# Going to see some garbage like in the nextpnr logs, print line and fail if (PASS at not there:
# Max frequency for clock 'clk_50mhz_fpga2$SB_IO_IN_$glb_clk': 89.35 MHz (PASS at 50.00 MHz)

def check_and_report_timing(next_pnr_log) -> bool:
    """
    Parse the nextpnr log and return a dictionary of timing information.
    """
    
    # Assume the log is already open
    # Want the post-routing timing
    post_router = False
    for line in next_pnr_log.splitlines():
        if "Info: Routing complete." in line:
            post_router = True
        if post_router and "Max frequency for clock" in line:
            print("\n" + line)
            if "(PASS at " in line:  
                return True
            else:
                break
    print("Error: Timing Failure")
    return False

def report_utilization(next_pnr_log) -> None:
    """
    Print a summary of the nextpnr log.
    """
    # Assume the log is already open
    printing = False
    for line in next_pnr_log.splitlines():
        if "Device utilisation:" in line:
            printing = True
            print("")
        if printing and  line.strip() == "":
            printing = False
        if printing:
            print(line)