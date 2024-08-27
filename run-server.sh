#!/usr/bin/env bash
set -euo pipefail

PORT=8000

# Function to kill processes on exit
cleanup() {
  echo "Stopping servers..."
  kill "$PYTHON_PID" "$NGROK_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Start Python HTTP server in the background
echo "Starting Python HTTP server..."
python -m http.server $PORT &
PYTHON_PID=$!

# Wait a moment for the server to start
sleep 2

# Start ngrok in the foreground
echo "Starting ngrok..."
NGROK_AUTHTOKEN=$(cat ~/.config/sops-nix/secrets/ngrok_authtoken)
ngrok http $PORT --authtoken "$NGROK_AUTHTOKEN" > ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to output the URL
echo "Waiting for ngrok to start..."
while ! curl -s http://localhost:4040/api/tunnels | grep -q "ngrok-free.app"; do
  sleep 1
done

# Extract and display the URL
PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "Your directory is now accessible at: $PUBLIC_URL"
echo "Press Ctrl+C to stop the servers."

wait "$PYTHON_PID"
