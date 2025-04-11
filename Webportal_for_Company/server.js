const WebSocket = require("ws");

const PORT = 3001; // WebSocket Server Port
const wss = new WebSocket.Server({ port: PORT });

console.log(`✅ WebSocket Server running on ws://0.0.0.0:${PORT}`);

wss.on("connection", (ws) => {
  console.log("🔗 Client connected");

  ws.on("message", (message) => {
    try {
      // Ensure received data is treated as a UTF-8 string
      const decodedMessage = message.toString("utf-8");
      console.log("📩 Received (decoded):", decodedMessage);

      // Parse the message as JSON
      const jsonData = JSON.parse(decodedMessage);
      console.log("📊 Parsed JSON:", jsonData);

      // Broadcast the parsed JSON data to all connected clients
      wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
          client.send(JSON.stringify(jsonData)); // Ensure data is sent as a JSON string
        }
      });
    } catch (error) {
      console.error("❌ Error processing WebSocket message:", error);
    }
  });

  ws.on("close", () => console.log("❌ Client disconnected"));
});
