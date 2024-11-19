-- In general, we're going to power a group on, and allow it 1ms to stabilize before starting the next group.
-- we could race so long as the next ground is <10% by the previous group's stabilization but no real need.
-- We have 3 power groups, A, B, and C as defined below:
-- A (G3/S5): VDDBT_RTC_G, VDD_18_S5,VDD_33_S5, VDDIO_AUDIO
-- B (S3): VDD_11_S3
-- C (S0): VDDIO, VDDCR_SOC,VDDCR_CPU0, VDDCR_CPU1
-- at least 1m before asserting POWER_GOOD

-- On power down, SLP_S3_L asserting, VDDIO, VDDCR_CPU0, VDDCR_CPU1 and VDDCR_SOC must begin decaying
-- On power down, SLP_S5_L asserting, VDD_11_S3 must begin decaying
-- If uncontrolled, RSMRST_L must be toggled before powering back up, and there are no sequencing reqts

-- RESET_L must remain asserted at least 1m after PWROK is asserted

-- Sequence as follows:
--  Enable Group A.
--  Wait for stable, then wait t1 (10ms) minimum
--  Release RSM_RST_L, then wait for 104 ms (RTC clk startup time, t2)
--  During t2, strobe PBTN LOW for 20 ms
-- At checkpoint, we should have SLP_S3_L and SLP_S5_L deasserted (high) and timer expired
-- Enable Group B, wait for stable and then 1ms minimum
-- Enable Group C, wait for firmware controlled power on to get PGs
-- Wait for for 1ms then assert PWR_GOOD
-- Wait for PWR_OK from AMD
-- Wait for RESET_L within 28.5ms of PWR_GOOD