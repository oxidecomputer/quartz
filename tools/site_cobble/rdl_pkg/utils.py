# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#

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


def _adoc_lines(value, escape_pipes=False):
    """
    Split a SystemRDL string property into stripped lines.

    RDL desc properties are routinely written as multi-line strings, so every
    continuation line carries the source indentation. None becomes an empty
    list rather than the string "None".
    """
    if value is None:
        return []
    lines = [line.strip() for line in str(value).splitlines()]
    if escape_pipes:
        lines = [line.replace("|", "\\|") for line in lines]
    return lines


def adoc_inline(value, default=""):
    """
    Collapse a property to a single line, for use in an AsciiDoc section title
    where a line break would end the title.
    """
    lines = [line for line in _adoc_lines(value) if line]
    return " ".join(lines) if lines else default


def adoc_cell(value, default=""):
    """
    Render a property as one AsciiDoc PSV table cell.

    An unescaped '|' would start a new cell and shift every following cell in
    the row, so pipes are escaped. Lines join with the AsciiDoc hard line break
    (' +') so the structure of things like enumerated bit encodings survives,
    and blank lines are dropped so a row can never be split early.
    """
    lines = [line for line in _adoc_lines(value, escape_pipes=True) if line]
    return " +\n".join(lines) if lines else default


def adoc_para(value, default=""):
    """
    Render a property as AsciiDoc body text outside a table: hard line breaks
    within a paragraph, blank lines between paragraphs. Pipes are left alone
    since they are not special outside a table.
    """
    paragraphs, current = [], []
    for line in _adoc_lines(value):
        if line:
            current.append(line)
        elif current:
            paragraphs.append(" +\n".join(current))
            current = []
    if current:
        paragraphs.append(" +\n".join(current))
    return "\n\n".join(paragraphs) if paragraphs else default
