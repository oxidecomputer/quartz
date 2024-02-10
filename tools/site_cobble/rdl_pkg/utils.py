# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2024 Oxide Computer Company

import inflection


def to_camel_case(template_string, uppercamel=False):
    return inflection.camelize(template_string, uppercase_first_letter=uppercamel)


def to_snake_case(template_string):
    return inflection.underscore(template_string)


def vhdl_bitstring(template_string, size):
    val = int(template_string, 0)
    return '"{0:0{1}b}"'.format(val, size)


def vhdl_2008_bitstring(template_string, size):
    if isinstance(template_string, str):
        val = int(template_string, 0)
    else:
        val = template_string
    return f'{size}x"{val:x}"'
