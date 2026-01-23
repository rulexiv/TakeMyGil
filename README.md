# TakeMyGil

![TakeMyGil](https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExdm12dTQ5cHY2Y3pleDdubTMxcTB0aGNxZWY0YWZxcXpscXhua2t1aiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/gvrnmr6mzJXBm/giphy.gif)

Automates sending gil via trade with a compact UI and progress tracking.

Version: 2.1.0

## Features
- Send mode with large-amount splitting
- Trade flow automation with confirmation handling
- Animated progress bar during active send
- Result summary on completion
- Mini SEND/RECV buttons for quick access

## Usage
1. Open the mini SEND button to show the main UI.
2. Enter the amount, use quick-add buttons if needed.
3. Press the main button to start (label stays the same; color indicates state).
4. Use the mini RECV button to toggle receive monitoring.

## Notes
- RECV cannot be started while SEND is running.
- The main UI is SEND-only; RECV is controlled from the mini button.
- When RECV is on, the top line shows “Receiver mode: on.”

## Installation
1. Copy the `TakeMyGil` folder to your FFXIVMinion LuaMods directory:
   `C:\MINIONAPP\Bots\FFXIVMinion64\LuaMods\`
2. In the Minion menu, go to **Reload Lua**.
3. The tracked bar will appear at the bottom right of the game window.
