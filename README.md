# Quartz

Quartz is a collection of soft-logic designs and hardware abstraction libraries (HALs) for various
subsystems found in Oxide hardware. This includes components such as Ignition, power sequencing for
system boards and QSFP interface management.

Quartz leans heavily on [Cobalt](https://github.com/oxidecomputer/cobalt) and unless a component is
experimental or specific to an Oxide system, our posture should be to push as much into that project
as possible. Having said that, it is acceptable to prototype in private under the Quartz project and
move something to Cobalt once deemed ready.
