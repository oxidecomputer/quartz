-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

--! Common shared information for arbiters
package arbiter_pkg is

    type arbiter_mode is (priority, round_robin);

end package;
