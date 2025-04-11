import requests

url = "http://127.0.0.1:5000/predict"
data = {"values": [10.5, 50.3, 22.1, 0.8, 90.0, 15.2]}  # Sample data

response = requests.post(url, json=data)
print(response.json())
