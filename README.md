# TakeMyGil

![TakeMyGil](https://preview.redd.it/man-i-am-hyped-v0-g7nvqbcomv4b1.jpg?width=640&crop=smart&auto=webp&s=d4cfc30f101e7cb92325ac189c37a9f1f0956655)

A trade helper that automates sending and receiving gil via the trade window.

Version: 2.1.0

## What it does
- Splits sending into 1,000,000 gil per trade (max total: 999,999,999)
- Moves into trade range and pauses movement before initiating trades
- Automates trade input, confirm, and final confirm
- Verifies trade completion by chat log and gil delta
- Shows progress + session stats while sending
- Mini SEND/RECV buttons at the bottom right

## How to use (Send)
1. Target the player you want to trade with.
2. Click the **SEND** mini button to open the main UI (the mini button hides while the UI is open).
3. Enter an amount or use +1M / +10M / +100M / ALL.
4. Press **SHUT UP AND TAKE MY GIL** to start.
   - Button color shows running/stopped.
5. While sending, a progress bar plus `Start / Current / Sent` values are shown.
6. When finished, `Total Time` and final stats are shown. Press the button to clear.

## How to use (Receive)
1. Toggle **RECV** using the mini button.
2. While enabled, Trade/Confirm dialogs are auto-accepted.
3. When RECV is on, the top line shows `RECV ON. SEND LOCKED.`

## Notes
- You cannot start RECV while SEND is running.
- SEND requires a valid trade target; it waits if the trade target mismatches.
- If the gil amount cannot be set reliably or the trade outcome is unclear, SEND stops for safety.
- Partner confirmation is timed out after 60 seconds and the trade is cancelled.
- If the trade closes unexpectedly, it checks chat/gil deltas to determine progress.

## Installation
1. Copy the `TakeMyGil` folder into your `LuaMods` directory:  
   `C:\MINIONAPP\Bots\FFXIVMinion64\LuaMods\`
2. In the Minion menu, choose **Reload Lua**.
3. The mini buttons will appear at the bottom right.
