# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

from systemrdl import RDLListener, AddrmapNode, RegfileNode, RegNode, FieldNode, MemNode

# This is a dumb hack to deal with the fact that buck2 and cobble run python differently
# and I couldn't figure out a way to make them both import the same way
try:
    from models import Register, Field, Memory
except ModuleNotFoundError:
    from rdl_pkg.models import Register, Field, Memory


# Define a listener that will print out the register model hierarchy
class MyModelPrintingListener(RDLListener):
    def __init__(self):
        self.indent = 0

    # noinspection PyPep8Naming
    def enter_Component(self, node):
        if not isinstance(node, FieldNode):
            print(" " * self.indent, node.get_path_segment())
            self.indent += 4

    # noinspection PyPep8Naming
    def enter_Reg(self, node):
        print(" " * self.indent, "Name:", node.get_property("name"))
        print(" " * self.indent, "Offset:", node.raw_address_offset)
        print(" " * self.indent, "Address:", node.absolute_address)

    # noinspection PyPep8Naming
    def enter_Field(self, node):
        # Print some stuff about the field
        if node.get_property("encode") is not None:
            my_enum = node.get_property("encode")
            print("Encode: {}".format(my_enum.type_name))
            print("Encode: {}".format(my_enum.members))
            for i in my_enum:
                print(f"Encode: {i.name}")
                print(f"Encode: {i.value}")
                print(f"Encode: {i.rdl_name}")
        bit_range_str = "[%d:%d]" % (node.high, node.low)
        sw_access_str = "sw=%s" % node.get_property("sw").name
        print(" " * self.indent, bit_range_str, node.get_path_segment(), sw_access_str)

    # noinspection PyPep8Naming
    def exit_Component(self, node):
        if not isinstance(node, FieldNode):
            self.indent -= 4

    # noinspection PyPep8Naming
    def enter_Mem(self, node):
        print(" " * self.indent, "Offset:", node.raw_address_offset)
        print(" " * self.indent, "Address:", node.absolute_address)
        print(" " * self.indent, "Entries:", node.get_property("mementries"))
        print(" " * self.indent, "Width:", node.get_property("memwidth"))


# Define a listener that will determine top Address map and other
# lower-level address maps
class PreExportListener(RDLListener):
    def __init__(self):
        self.maps = []  # List[Node]

    def enter_Addrmap(self, node: AddrmapNode) -> None:
        # If we're to top map, we only have AddrmapNodes as children
        self.maps.append(node)

    @property
    def is_map_of_maps(self):
        return all(map(lambda x: isinstance(x, AddrmapNode), self.maps[0].children()))


class BaseListener(RDLListener):
    def __init__(self):
        self.prefix_stack = []
        self.known_types = []
        self.reset_by_known_type = {}  # A dictionary for looking up reset values by their known-type names
        self.cur_reg = None
        self.registers = []

    def enter_Addrmap(self, node: AddrmapNode) -> None:
        # print(f"Enter Addrmap: {node.inst_name}")
        if not self.is_map_of_maps(node):  # skip appending the map of maps prefix
            self.prefix_stack.append(node.inst_name)

    def exit_Addrmap(self, node: AddrmapNode) -> None:
        if not self.is_map_of_maps(node):  # skip popping the map of maps prefix
            self.prefix_stack.pop()

    def enter_Regfile(self, node: RegfileNode) -> None:
        # print(f"Enter Regfile: {node.inst_name}")
        self.prefix_stack.append(node.inst_name)

    def exit_Regfile(self, node: RegfileNode) -> None:
        self.prefix_stack.pop()

    def enter_Regfile(self, node: RegfileNode) -> None:
        self.prefix_stack.append(node.inst_name)

    def exit_Regfile(self, node: RegfileNode) -> None:
        self.prefix_stack.pop()

    def enter_Reg(self, node: RegNode) -> None:
        # 2 cases here:
        # node.orig_type_name is None, use node.type_name
        #

        if (node.type_name in self.known_types) or (
            node.orig_type_name is not None and node.orig_type_name in self.known_types
        ):
            repeated_type = True
        else:
            if node.orig_type_name is not None:
                self.known_types.append(node.orig_type_name)
            else:
                self.known_types.append(node.type_name)
            repeated_type = False
        self.cur_reg = Register.from_node(node, self.prefix_stack, repeated_type)

    def exit_Reg(self, node):
        """
        When we exit a register, we know it's configuration is complete
        so we run the elaborate method which sorts it, and enumerates
        and fills in the reserved holes, and sorts again. This register
        is then appended list of registers to be used
        in generation of design collateral.
        """
        self.cur_reg.elaborate()
        self.registers.append(self.cur_reg)
        # If not a repeated type, put the reset value which we now know into a dictionary lookup
        if not self.cur_reg.repeated_type:
            self.reset_by_known_type[self.cur_reg.type_name] = self.cur_reg.elaborated_reset, self.cur_reg.prefixed_name
        else:
            # If it was a repeated type, check that the reset value here matches the default reset value
            base_reset, base_name = self.reset_by_known_type.get(self.cur_reg.type_name)
            reg_reset = self.cur_reg.elaborated_reset
            
            # base reset is None, we'll allow None, 1s or 0s, nothing else. Anything else is an error
            if base_reset is None and not (self.cur_reg.reset_is_all_1s or self.cur_reg.reset_is_all_0s or reg_reset is None):
                raise ValueError(
                   f"Reset value '{reg_reset}'for register {self.cur_reg.prefixed_name} is not all 1s or all 0s, "
                   "and there's no default reset value for the type. The RDL subsystem doesn't support this pattern. "
                   "Please check that you can't use a default value for the type, or elide the special reset value"
                   " from the RDL and implement it in your own logic. You may also file an enhancement request to "
                   "figure out how to better support this pattern."
                )
            elif reg_reset != base_reset and base_reset is not None:
                raise ValueError(
                   f"Reset value '{reg_reset}' for register {self.cur_reg.prefixed_name} does not match reset value '{base_reset}'"
                   f" already defined for that type: {base_name}.\n"
                   "This is likely due to a reset value override on an instance of the type that is conflicting "
                   f"with a default value on the shared type '{self.cur_reg.type_name}'"

                )
        self.cur_reg = None

    def enter_Field(self, node) -> None:
        # print(f"Enter Field: {node.inst_name}")
        """
        Each field we find, we generate a Field from the node and
        append it to the fields list of our current register.
        """
        self.cur_reg.fields.append(Field.from_node(node))

    def enter_Mem(self, node: MemNode) -> None:
        pass

    def exit_Mem(self, node) -> None:
        if (node.type_name in self.known_types) or (
            node.orig_type_name is not None and node.orig_type_name in self.known_types
        ):
            repeated_type = True
        else:
            if node.orig_type_name is not None:
                self.known_types.append(node.orig_type_name)
            else:
                self.known_types.append(node.type_name)
            repeated_type = False
        self.registers.append(Memory.from_node(node, self.prefix_stack, repeated_type))

    @staticmethod
    def is_map_of_maps(node):
        return all(map(lambda x: isinstance(x, AddrmapNode), node.children()))
