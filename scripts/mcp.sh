#!/bin/bash

# MCP (Model Context Protocol) Tool Calling Demo
# This demonstrates how tool calling works WITHOUT an actual MCP server
# Everything is simulated via API calls to show the concept clearly

if [ -z "${OPENROUTER_API_KEY}" ]; then
  echo "ERROR: OPENROUTER_API_KEY environment variable is not set"
  exit 1
fi

echo "🔧 MCP TOOL CALLING DEMONSTRATION"
echo "===================================="
echo ""

MODEL='nvidia/nemotron-nano-12b-v2-vl:free'

# STEP 1: Define the tool (weather function)
# This is what the LLM will "see" and can choose to call
WEATHER_TOOL='{
  "type": "function",
  "function": {
    "name": "get_current_weather",
    "description": "Get the current weather for a given location",
    "parameters": {
      "type": "object",
      "properties": {
        "location": {
          "type": "string",
          "description": "The city name, e.g. San Francisco"
        },
        "unit": {
          "type": "string",
          "enum": ["celsius", "fahrenheit"],
          "description": "The temperature unit"
        }
      },
      "required": ["location"]
    }
  }
}'

echo "📦 STEP 1: Tool Definition"
echo "We're giving the LLM access to this tool:"
echo "$WEATHER_TOOL" | jq '.'
echo ""
echo "Press Enter to continue..."
read

# STEP 2: Ask the LLM a question that requires the tool
USER_QUESTION="What's the weather like in San Francisco today?"

echo "💬 STEP 2: User asks a question"
echo "Question: $USER_QUESTION"
echo ""

# Build the initial request with tools
INITIAL_REQUEST=$(jq -n \
  --arg model "$MODEL" \
  --arg question "$USER_QUESTION" \
  --argjson tool "$WEATHER_TOOL" \
  '{
    "model": $model,
    "messages": [
      {"role": "user", "content": $question}
    ],
    "tools": [$tool]
  }')

echo "🌐 STEP 3: Sending request to LLM WITH tool definition"
echo "Request payload:"
echo "$INITIAL_REQUEST" | jq '.'
echo ""
echo "Press Enter to continue..."
read

# Make the API call
RESPONSE=$(curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$INITIAL_REQUEST")

echo "📥 STEP 4: LLM Response (requesting to call tool)"
echo "$RESPONSE" | jq '.'
echo ""

# Extract the tool call from response
TOOL_CALL=$(echo "$RESPONSE" | jq -r '.choices[0].message.tool_calls[0] // empty')

if [ -z "$TOOL_CALL" ]; then
  echo "⚠️  LLM did not request a tool call. Response:"
  echo "$RESPONSE" | jq -r '.choices[0].message.content'
  exit 0
fi

echo "🔍 STEP 5: Parsing the tool call request"
FUNCTION_NAME=$(echo "$TOOL_CALL" | jq -r '.function.name')
FUNCTION_ARGS=$(echo "$TOOL_CALL" | jq -r '.function.arguments')
TOOL_CALL_ID=$(echo "$TOOL_CALL" | jq -r '.id')

echo "Function to call: $FUNCTION_NAME"
echo "Arguments: $FUNCTION_ARGS"
echo "Tool Call ID: $TOOL_CALL_ID"
echo ""
echo "Press Enter to continue..."
read

# STEP 6: Execute the tool (simulated with hardcoded data)
echo "⚙️  STEP 6: Executing tool call (simulated)"
echo "In a real MCP setup, this would call an actual weather API"
echo "For this demo, we're returning hardcoded data..."
echo ""

LOCATION=$(echo "$FUNCTION_ARGS" | jq -r '.location')

# Simulate the tool execution with hardcoded response
TOOL_RESULT='{
  "location": "'"$LOCATION"'",
  "temperature": 72,
  "unit": "fahrenheit",
  "conditions": "sunny",
  "humidity": 65,
  "wind_speed": 8
}'

echo "📊 Tool Result (hardcoded):"
echo "$TOOL_RESULT" | jq '.'
echo ""
echo "Press Enter to continue..."
read

# STEP 7: Send the tool result back to the LLM
echo "🔄 STEP 7: Sending tool result back to LLM"

# Build conversation with tool result
FOLLOWUP_REQUEST=$(jq -n \
  --arg model "$MODEL" \
  --arg question "$USER_QUESTION" \
  --argjson tool "$WEATHER_TOOL" \
  --arg tool_call_id "$TOOL_CALL_ID" \
  --arg function_name "$FUNCTION_NAME" \
  --arg function_args "$FUNCTION_ARGS" \
  --argjson tool_result "$TOOL_RESULT" \
  '{
    "model": $model,
    "messages": [
      {"role": "user", "content": $question},
      {
        "role": "assistant",
        "content": null,
        "tool_calls": [{
          "id": $tool_call_id,
          "type": "function",
          "function": {
            "name": $function_name,
            "arguments": $function_args
          }
        }]
      },
      {
        "role": "tool",
        "tool_call_id": $tool_call_id,
        "content": ($tool_result | tostring)
      }
    ],
    "tools": [$tool]
  }')

echo "Request with tool result:"
echo "$FOLLOWUP_REQUEST" | jq '.'
echo ""
echo "Press Enter to continue..."
read

# Make the final API call
FINAL_RESPONSE=$(curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$FOLLOWUP_REQUEST")

echo "📥 STEP 8: Final LLM Response"
echo "$FINAL_RESPONSE" | jq '.'
echo ""

FINAL_MESSAGE=$(echo "$FINAL_RESPONSE" | jq -r '.choices[0].message.content')

echo "=========================================="
echo "✅ FINAL ANSWER TO USER"
echo "=========================================="
echo ""
echo "$FINAL_MESSAGE"
echo ""
echo "=========================================="
echo "🎓 SUMMARY: How MCP/Tool Calling Works"
echo "=========================================="
echo ""
echo "1. Client defines tools/functions available to LLM"
echo "2. User asks a question"
echo "3. LLM receives question + tool definitions"
echo "4. LLM decides to call a tool (returns function call request)"
echo "5. Client executes the function (in real MCP, this calls a server)"
echo "6. Client sends tool result back to LLM"
echo "7. LLM reads result and generates natural language response"
echo "8. User gets final answer!"
