# TakeMyGil

![TakeMyGil](https://preview.redd.it/man-i-am-hyped-v0-g7nvqbcomv4b1.jpg?width=640&crop=smart&auto=webp&s=d4cfc30f101e7cb92325ac189c37a9f1f0956655)

A simple, user-friendly trade helper to send gil smoothly.

Version: 2.1.0

## What it does
- Automatically splits into 1,000,000 gil per trade
- Walks into trade range before sending a request
- Automates input, confirm, and final confirm
- Shows progress while sending
- Shows results after completion (Sent / Time)
- Mini SEND/RECV buttons at the bottom right for quick access

## How to use (Send)
1. Click the **SEND** mini button to open the main UI.
2. Enter an amount or use +1M / +10M / +100M / ALL.
3. Press **SHUT UP AND TAKE MY GIL** to start.
   - Button color shows running/stopped.
4. While sending, `Sending...` and a progress bar appear.
5. When finished, `Sent` and `Time` are shown. Press the button to stop and clear.

## How to use (Receive)
1. Toggle **RECV** using the mini button.
2. While enabled, trade/confirm dialogs are auto-accepted.
3. When RECV is on, the top line shows `RECV ON. SEND LOCKED.`

## Notes
- You cannot start RECV while SEND is running.
- If the gil amount cannot be set reliably, the send stops for safety.
- If the other player is AFK, the addon will wait indefinitely.

## Installation
1. Copy the `TakeMyGil` folder into your `LuaMods` directory:  
   `C:\MINIONAPP\Bots\FFXIVMinion64\LuaMods\`
2. In the Minion menu, choose **Reload Lua**.
3. The mini buttons will appear at the bottom right.
