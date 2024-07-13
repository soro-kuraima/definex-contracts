#!/bin/bash

# Replace with your target address and RPC URL
ADDRESS="0x09c2411420fB52F9705C01F25DFA488CDbA7C1bE"
RPC_URL="http://54.226.158.187"

# Get the latest block number
LATEST_BLOCK=$(cast block-number --rpc-url $RPC_URL)

# Initialize counters
FOUND_TXS=0
BLOCK=$LATEST_BLOCK

echo "Searching for the last 10 transactions of address $ADDRESS"

while [ $FOUND_TXS -lt 2 ] && [ $BLOCK -gt 0 ]
do
    # Get block info
    BLOCK_INFO=$(cast block $BLOCK --rpc-url $RPC_URL)
    
    # Check if the block contains our address
    if echo "$BLOCK_INFO" | grep -q "$ADDRESS"; then
        # Extract transaction hashes
        TXS=$(echo "$BLOCK_INFO" | grep "transactions" | cut -d '[' -f2 | cut -d ']' -f1 | tr ',' '\n' | sed 's/^[ \t]*//' | sed 's/"//g')
        
        for TX in $TXS
        do
            if [ ! -z "$TX" ]; then
                # Get transaction info
                TX_INFO=$(cast tx $TX --rpc-url $RPC_URL 2>/dev/null)
                if [ $? -eq 0 ] && echo "$TX_INFO" | grep -q "$ADDRESS"; then
                    echo "Transaction found in block $BLOCK:"
                    echo "$TX_INFO"
                    echo "------------------------"
                    FOUND_TXS=$((FOUND_TXS + 1))
                    
                    if [ $FOUND_TXS -eq 2 ]; then
                        break 2
                    fi
                fi
            fi
        done
    fi
    
    BLOCK=$((BLOCK - 1))
done

echo "Found $FOUND_TXS transactions for address $ADDRESS"