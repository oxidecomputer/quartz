# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import copy
from typing import List, Tuple

from systemrdl import RegNode, FieldNode, MemNode


class UnsupportedRegisterSizeError(Exception):
    pass


class DuplicateEnumNameError(Exception):
    pass


class BaseModel:
    @classmethod
    def from_node(cls, node: RegNode, prefix_stack, repeated_type=False, base_reset=None):
        return cls(node=node, prefix_stack=prefix_stack, repeated_type=repeated_type, base_reset=base_reset)

    def __init__(self, **kwargs):
        self.prefix = copy.deepcopy(kwargs.pop("prefix_stack"))
        self.repeated_type = kwargs.pop("repeated_type")
        self.enum_names = set()
        self.node = kwargs.pop("node")
        self.width = self.node.size * 8  # node.size is bytes, we want bits here
        self.type_name = (
            self.node.type_name
            if self.node.orig_type_name is None
            else self.node.orig_type_name
        )
        # Want offset from owning address map.
        self.offset = self.node.absolute_address
        self.fields = []
        self._max_field_name_chars = 0

    @property
    def prefixed_name(self) -> str:
        return "_".join(self.prefix) + "_" + self.node.get_path_segment()

    @property
    def name(self) -> str:
        # We're generating address maps but we can skip the first address map name, but we want the rest of the elaboration
        return (
            "_".join(self.prefix[1:]) + "_" + self.node.get_path_segment()
            if len(self.prefix) > 1
            else self.node.get_path_segment()
        )
    
    @property
    def fields_by_bytes(self) -> List[List[Tuple[Tuple[int,int], "Field"]]]:
        view_files_in_bytes = []
        for byte_high_index in range(0, self.node.size):
            high = self.width - 1 - 8 * byte_high_index
            low = self.width -1 - 8 * byte_high_index - 7
            view_files_in_bytes.append(((high, low), self.fields_between_bits(high, low)))
        return view_files_in_bytes

    
    def fields_between_bits(self, high: int, low: int) -> List["Field"]:
        # loop fields throwing them away until we find one or more that is/are in our desired bit-range
        # return a view of that field, possibly limited by our ranges
        view_fields = []
        for field in self.fields:
            # Field is totally contained within given bit constraints
            if field.high <= high and field.low >= low:
                view_fields.append(field)
            # Sliced high portion, so high is in range
            # but the field's low is out of range
            elif (field.high <= high and field.high >= low):
                  new_field = copy.deepcopy(field)
                  # Re-write low to this new value
                  new_field.low = low;
                  view_fields.append(new_field)
            # Sliced low portion, so low is in range
            # but the field's high is out of range
            elif (field.low <= high and field.low > low):
                new_field = copy.deepcopy(field)
                new_field.high = high
                view_fields.append(new_field)
            # Field is larger than constraints but contains
            # the whole constraint range so we need to chop
            # high and low sides of the field
            elif (high >= field.low and low <= field.high):
                new_field = copy.deepcopy(field)
                new_field.high = high
                new_field.low = low
                view_fields.append(new_field)
        return view_fields



    def get_property(self, *args, **kwargs):
        """
        Helper function to get RDL property from this register node.
        """
        try:
            prop = self.node.get_property(*args, **kwargs)
        except AttributeError:
            prop = ""
        return prop


class Register(BaseModel):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @property
    def used_bits(self) -> int:
        return sum([x.width for x in self.packed_fields])

    @property
    def packed_fields(self) -> List["Field"]:
        """
        Returns all the defined register fields, skipping any ReservedFields (undefined spaces)
        """
        return [x for x in self.fields if not isinstance(x, ReservedField)]

    @property
    def encoded_fields(self) -> List["Field"]:
        """
        Returns any register fields that have encodings
        """
        return [x for x in self.packed_fields if x.has_encode()]
    
    @property
    def has_encoded_fields(self) -> bool:
        """
        True if any fields have an encoding, meaning we'll generate enumerated types for them
        """
        return len(self.encoded_fields) > 0
    
    @property
    def reset_is_all_1s(self) -> bool:
        """
        True if all defined, non-reserved fields have a reset value of all 1s
        """
        for field in self.fields:
            rst_prop = field.get_property("reset")
            if (not isinstance(field, ReservedField) and 
                (rst_prop is not None) and 
                rst_prop != field.reset_1s):
                    return False
        return True
    
    @property
    def reset_is_all_0s(self) -> bool:
        """
        True if all defined, non-reserved fields have a reset value of all 0s
        """
        return self.elaborated_reset == 0
    
    @property
    def elaborated_reset(self) -> int:
        """
        Returns the combined reset value of the register post elaboration, if it has one.
        """
        if not self.has_reset_definition:
            return None
        reset_val = 0
        for field in self.fields:
            if (field.get_property("reset") is not None) and (not isinstance(field, ReservedField)):
                reset_val |= field.get_property("reset") << field.low
        return reset_val

    @property
    def has_reset_definition(self) -> bool:
        """
        RDL doesn't force a reset definition on registers but we may want to conditionally generate
        reset logic if a reset value was specified.
        """
        # Get the reset value for all the fields. If we don't see None in any of them we have defined reset behavior
        a = [
            x.get_property("reset")
            for x in self.fields
            if not isinstance(x, ReservedField)
        ]
        return False if None in a else True

    def elaborate(self) -> None:
        """
        Register elaboration consists of sorting the defined fields by the
        low index of the field. We then loop through the fields and
        determine the largest contiguous gaps in the definitions and creating
        ReservedFields that fill into these spaces. These are accumulated in
        a gaps variable, and the gaps and fields are concatenated and
        re-sorted by low index again at the end.
        """
        if self.width not in [8, 16, 32]:
            raise UnsupportedRegisterSizeError(
                f"We only support 8/16/32bit registers at this time. Register {self.name} has a width of {self.width}"
            )

        # sort fields descending by field.low bit
        self.fields.sort(key=lambda x: x.low, reverse=True)
        field_max_name = max(len(fld.name) for fld in self.fields)

        # keep a running size of the largest field name to help with formatting
        self._max_field_name_chars = max(self._max_field_name_chars, field_max_name)

        # find gaps and fill in with ReservedFields
        gaps = []
        expected = self.width - 1
        for field in self.fields:
            if field.high != expected:
                gaps.append(ReservedField(expected, field.high + 1))
            expected = field.low - 1

        if expected >= 0:
            gaps.append(ReservedField(expected, 0))

        # Combine fields and re-sort, leaving us with a completely specified register
        self.fields = sorted(self.fields + gaps, key=lambda x: x.low, reverse=True)

    def format_field_name(self, name) -> str:
        """
        To nicely generate aligned outputs, it's handy to know the max length
        of the names of fields on a per-register basis, this function
        provides formatting padded to the max-length for this purpose. This is
        only "known" at the register level but desired in templates at the
        "field" level so the templates can use this function as necessary.
        """
        return f"{name:<{self._max_field_name_chars}}"


class BaseField:
    """A base class with common implementations for fields"""

    def bsv_bitslice_str(self) -> str:
        if self.high == self.low:
            return str(self.low)
        else:
            return f"{self.high}:{self.low}"

    def vhdl_bitslice_str(self) -> str:
        if self.high == self.low:
            return str(self.low)
        else:
            return f"{self.high} downto {self.low}"
    
    def text_bitslice_str(self) -> str:
        if self.high == self.low:
            return str(self.low)
        else:
            return f"{self.high}..{self.low}"

    @property
    def width(self) -> int:
        return (self.high - self.low) + 1

    @property
    def mask(self) -> int:
        return ((1 << self.width) - 1) << self.low

    def get_property(self, *args, **kwargs):
        try:
            prop = self.node.get_property(*args, **kwargs)
        except AttributeError:
            prop = ""
        return prop

    @property
    def reset_str(self) -> str:
        my_rst = self.node.get_property("reset")
        return "{:#0x}".format(my_rst) if my_rst is not None else "None"

    @property
    def vhdl_reset_or_default(self) -> str:
        my_rst = self.node.get_property("reset")
        reset_val = 0 if my_rst is None else my_rst
        if self.width > 1:
            return f'{self.width}x"{reset_val:X}"'
        else:
            return f"'{reset_val:1X}'"
        
    @property
    def reset_1s(self) -> int:
        if self.width > 1:   
            return (1 << self.width) - 1
        else:
            return 1
    
    @property
    def vhdl_reset_1s(self) -> str:
        if self.width > 1:
            reset_val = (1 << self.width) - 1
            return f'{self.width}x"{reset_val:X}"'
        else:
            reset_val = 1
            return f"'{reset_val:1X}'"
        
    @property
    def vhdl_reset_0s(self) -> str:
        reset_val = 0
        if self.width > 1:
            return f'{self.width}x"{reset_val:X}"'
        else:
            return f"'{reset_val:1X}'"

    def has_encode(self) -> bool:
        return False
    
    def __str__(self):
        return f'{type(self)} ({self.name}): high: {self.high} low: {self.low}'


class Field(BaseField):
    """A normal, systemRDL-defined field"""

    @classmethod
    def from_node(cls, node: FieldNode):
        return cls(node=node)

    def __init__(self, **kwargs):
        self.node = kwargs.pop("node")
        self.name = self.node.get_path_segment()
        self.high = self.node.high
        self.low = self.node.low
        self.desc = self.node.get_property("desc")

    def has_encode(self):
        return self.node.get_property("encode") is not None

    def encode_enums(self):
        return list(
            [
                (x.name, x.value)
                for x in self.node.get_property("encode")
                if self.has_encode()
            ]
        )


class ReservedField(BaseField):
    """A reserved field, inferred by the gaps in systemRDL definitions"""

    def __init__(self, high, low):
        self.name = "-"
        self.node = None
        self.high = high
        self.low = low
        self.desc = "Reserved"


class Memory(BaseModel):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
