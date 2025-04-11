"use client";

import { useEffect, useState } from "react";

export default function Page() {
  const [queries, setQueries] = useState([]);

  useEffect(() => {
    const socket = new WebSocket("ws://localhost:3001");

    socket.onopen = () => console.log("✅ WebSocket connected");
    socket.onerror = (error) => console.error("❌ WebSocket error:", error);
    socket.onclose = () => console.log("⚠️ WebSocket disconnected");

    socket.onmessage = async (event) => {
      try {
        let messageData = event.data;
        if (messageData instanceof Blob) {
          messageData = await messageData.text();
        }
    
        if (messageData instanceof ArrayBuffer) {
          messageData = new TextDecoder("utf-8").decode(messageData);
        }
    
        console.log("📩 Raw WebSocket message:", messageData);
    
        const newData = JSON.parse(messageData);
        console.log("📊 Parsed JSON:", newData);
    
        setQueries((prevQueries) => [...prevQueries, newData]);
      } catch (error) {
        console.error("❌ Error parsing WebSocket data:", error);
      }
    };
    

    return () => {
      console.log("🔌 Closing WebSocket connection...");
      socket.close();
    };
  }, []);

  return (
    <div className="container">
      <h2>Live Efficiency Reports</h2>
      <div className="cards">
        {queries.length === 0 ? (
          <p>No data received yet...</p>
        ) : (
          queries.map((query, index) => (
            <div key={index} className="card">
              <h3>Efficiency Score: {query.efficiency_score.toFixed(2)}</h3>
              <p>{query.analyze_issue}</p>
              <p>
                <strong>Booked Time:</strong>{" "}
                {new Date(query.booked_time).toLocaleString()}
              </p>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
