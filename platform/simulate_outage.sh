#!/bin/bash
set -e

ENV_ID=""
MODE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV_ID="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$ENV_ID" ] || [ -z "$MODE" ]; then
    echo "Usage: simulate_outage.sh --env <ENV_ID> --mode <crash|pause|network|recover|stress>"
    exit 1
fi

CONTAINER_NAME="app-$ENV_ID"

if [[ "$CONTAINER_NAME" == *"nginx"* ]] || [[ "$CONTAINER_NAME" == *"daemon"* ]]; then
    echo "❌ Safety guard: Cannot simulate outage on system containers!"
    exit 1
fi

if ! docker ps -a 2>/dev/null | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container not found: $CONTAINER_NAME"
    exit 1
fi

echo "Simulating outage: $MODE on $ENV_ID"

case $MODE in
    crash)
        echo "Crashing container..."
        docker kill $CONTAINER_NAME 2>/dev/null || true
        echo "✅ Container crashed. Health monitor should detect within 90s"
        ;;
    pause)
        echo "Pausing container..."
        docker pause $CONTAINER_NAME 2>/dev/null || true
        echo "✅ Container paused"
        ;;
    unpause|recover)
        echo "Unpausing container..."
        docker unpause $CONTAINER_NAME 2>/dev/null || true
        echo "✅ Container recovered"
        ;;
    network)
        echo "Disconnecting from network..."
        NETWORK_NAME="sandbox-$ENV_ID"
        docker network disconnect $NETWORK_NAME $CONTAINER_NAME 2>/dev/null || true
        echo "✅ Network disconnected"
        ;;
    stress)
        echo "Stressing CPU..."
        docker exec $CONTAINER_NAME python3 -c "sum(range(1000000000))" 2>/dev/null || echo "⚠️  Stress failed"
        echo "✅ Stress applied"
        ;;
    *)
        echo "Unknown mode: $MODE"
        exit 1
        ;;
esac

echo "Done!"

