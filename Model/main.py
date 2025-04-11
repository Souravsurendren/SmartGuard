from flask import Flask, request, jsonify
import onnxruntime as ort
import numpy as np
import google.generativeai as genai
import json

app = Flask(__name__)

# ✅ Configure Gemini API (Using your API Key)
genai.configure(api_key="AIzaSyA7ZmjqgqyNjb1JmjlcLgFM1XPO2Rx32gs")  

# ✅ Load ONNX Model
onnx_model_path = r"catboost_model.onnx"  # Ensure correct path
session = ort.InferenceSession(onnx_model_path)

def analyze_issue_user(input_data, efficiency_score):
    prompt = f"""
    You are an virtual EV statistical data analysis agent, you get data from various EVs and analyze the efficiency of the EVs.
    
    Analyze the following EV efficiency anomaly. The efficiency score is {efficiency_score}, which is below the optimal threshold of 88.
    The parameters format are : Battery_Voltage	Battery_Temperature	SOC	Battery_Current	Motor_Temperature	Motor_Speed	Power_Output	Torque	Charging_Power	Charging_Time	Chg_Overcurrent_Level_1	Chg_Overcurrent_Level_2	Dischg_Overcurrent_Level_1	Dischg_Overcurrent_Level_2	Cell_Volt_High_Level_1	Cell_Volt_High_Level_2	Cell_Volt_Low_Level_1	Cell_Volt_Low_Level_2	Sum_Volt_High_Level_1	Sum_Volt_Low_Level_2	Chg_Temp_High_Level_1	Chg_Temp_Low_Level_2	Dischg_Temp_High_Level_1	Dischg_Temp_Low_Level_2	Short_Circuit_Protect_Fault	Communication_Failure	Cooling_System_Failure	Efficiency_Score
    Given the input parameters:
    
    {json.dumps(input_data, indent=2)}
    
    Now in one line tell user more conviniently so that they wont get threatened with this message but notified to visit the service center with "level 1" indication if its not a big issue and visiting store in a week else "level 2" if its a big issue visiting store within a day is necessary.
    """

    model = genai.GenerativeModel("gemini-2.0-flash")
    response_user = model.generate_content(prompt)

    return response_user.text
# ✅ Function to analyze low efficiency issues
def analyze_issue(input_data, efficiency_score):
    prompt = f"""
    You are a virtual EV statistical data analysis agent analyzing efficiency anomalies.
    
    The efficiency score is {efficiency_score}, which is below the optimal threshold of 87.
    Given the input parameters:
    
    {json.dumps(input_data, indent=2)}
    
    Provide a short report explaining potential root causes (5-7 lines).
    Also, suggest a time frame for taking the EV to the service center.
    """

    try:
        model = genai.GenerativeModel("gemini-2.0-flash")  # ✅ Using your original model
        response = model.generate_content(prompt)
        return response.text if response else "Error: No response from AI."
    except Exception as e:
        return f"Error in Gemini API: {str(e)}"

# ✅ Combined Prediction & Analysis Endpoint
@app.route('/predict', methods=['POST'])
def predict():
    try:
        # 🔹 Get input data from the request
        data = request.json.get("values")
        if not data:
            return jsonify({"error": "Missing input data"}), 400
        
        # 🔹 Convert input data to NumPy float32
        input_data = np.array(data, dtype=np.float32).reshape(1, -1)
        
        # 🔹 Run inference
        input_name = session.get_inputs()[0].name
        output_name = session.get_outputs()[0].name
        output = session.run([output_name], {input_name: input_data})[0]
        efficiency_score = output[0][0]
        
        # 🔹 Prepare response
        response_data = {"efficiency_score": float(efficiency_score)}
        response_data_user = {"efficiency_score": float(efficiency_score)}

        # 🚀 If efficiency is below threshold, analyze the issue automatically
        if efficiency_score < 88:
            report = analyze_issue(data, efficiency_score)
            report_user = analyze_issue_user(data, efficiency_score)
            response_data["analysis_report"] = report
            response_data_user["analysis_report_user"] = report_user

        return jsonify(response_data,response_data_user)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ Run Flask app on 0.0.0.0 (accessible on network) and port 8080
if __name__ == '__main__':
    app.run(host="0.0.0.0", port=8080, debug=True)
