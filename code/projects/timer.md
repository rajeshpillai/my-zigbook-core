# Timer Implementation Walkthrough

## Supported Formats:

10s (Seconds)
1.5m (Minutes)
2h (Hours)

## Animation
The timer now uses ANSI escape codes to:

- Clear the screen (\x1b[2J)
- Hide the cursor (\x1b[?25l)
- Move output to the center of the terminal (\x1b[12;40H)
- Display the time as MM:SS or S depending on duration.

## Sample Runs
Test Case 1: Seconds
Command: zig run timer.zig -- 2s 

Test Case 2: Minutes
Command: zig run timer.zig -- 1.1m Result:

Parsed as 66 seconds.
Displayed 01:06, 01:05... correctly counting down.