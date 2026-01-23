# TakeMyGil

![TakeMyGil](https://preview.redd.it/man-i-am-hyped-v0-g7nvqbcomv4b1.jpg?width=640&crop=smart&auto=webp&s=d4cfc30f101e7cb92325ac189c37a9f1f0956655)

Automates sending gil via trade with a compact UI and progress tracking.

Version: 2.1.0

## Features
- Send mode with 1,000,000 gil splitting per trade
- Auto-approach target before sending trade request
- Automated trade flow (input, confirm, final confirm)
- Animated progress bar during active send (left-to-right scan)
- Result summary on completion
- Mini SEND/RECV buttons for quick access

## Usage
1. Open the mini SEND button to show the main UI.
2. Enter the amount, use quick-add buttons if needed.
3. Press the main button to start (label stays the same; color indicates state).
4. Use the mini RECV button to toggle receive monitoring.
5. After completion, the button stays “on” (green) and the result is shown; press the main button to stop and clear it.

## Notes
- RECV cannot be started while SEND is running.
- The main UI is SEND-only; RECV is controlled from the mini button.
- When RECV is on, the top line shows “RECV ON. SEND LOCKED.” (amount stays in the input).
- Trade amount verification is performed before confirming; if it cannot be set reliably, the send stops.

## Installation
1. Copy the `TakeMyGil` folder to your FFXIVMinion LuaMods directory:
   `C:\MINIONAPP\Bots\FFXIVMinion64\LuaMods\`
2. In the Minion menu, go to **Reload Lua**.
3. The tracked bar will appear at the bottom right of the game window.
