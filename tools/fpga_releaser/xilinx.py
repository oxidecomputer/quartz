def check_and_report_timing(timing_log) -> bool:
    start = False
    pause = False

    for line in timing_log.splitlines():
        if not start and "Design Timing Summary" in line:
            start = True
            pause = True
        
        if start and pause and "WNS(ns)" in line:
            pause = False
        
        if start and not pause and line.strip():
            print(line)
        elif start and not pause and line.strip() == "":
            stop = True

        if "All user specified timing constraints are met." in line:
            print(line)
            return True
        if "Timing constraints are not met." in line:
            print(line)
            return False


def report_utilization(utilization_log) -> None:
    last_line = ""
    start = False
    pause = False

    for line in utilization_log.splitlines():
        if not start and "1. Slice Logic" in line:
            start = True
            pause = True
        
        if start and pause and "Site Type" in line:
            print(last_line)
            pause = False
        
        if start and not pause and line.strip():
            print(line)
        elif start and not pause and line.strip() == "":
            stop = True
            pause = False
        
        if not start and "3. Memory" in line:
            pause = True

        last_line = line