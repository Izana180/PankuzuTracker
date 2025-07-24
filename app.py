import os
import openai
import json
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
# 1. 重新导入 python-dotenv 库
from dotenv import load_dotenv

# --- 初始化 ---
# 2. 在程序开始时加载 .env 文件 (这主要用于本地开发)
# 在 Render 上，环境变量会由平台直接提供
load_dotenv()

app = Flask(__name__, static_folder='static')
CORS(app) 

# --- 配置 OpenAI API 客户端 ---
# 3. 从环境变量中安全地读取 API 密钥
api_key = os.getenv("OPENAI_API_KEY")

# 增加一个检查，如果密钥不存在则打印错误并退出
if not api_key:
    raise ValueError("OpenAI APIキーが設定されていません。環境変数 'OPENAI_API_KEY' を設定してください。")

client = openai.OpenAI(api_key=api_key)


# --- 算法与辅助函数 ---
def classify_movement(accel_data):
    if not accel_data or accel_data.get('x') is None:
        return {"status": "不明"}
    try:
        a = {k: float(v) for k, v in accel_data.items()}
        m = (a['x']**2 + a['y']**2 + (a['z'] - 9.8)**2)**0.5
        if m < 0.5: return {"status": "静止"}
        if m < 2.0: return {"status": "歩行"}
        if m < 5.0: return {"status": "走行"}
        return {"status": "激しい運動"}
    except (ValueError, TypeError):
        return {"status": "不明"}

# --- API 接口 (Endpoints) ---

@app.route('/health')
def health_check():
    """一个简单的健康检查接口"""
    print("[DEBUG] Health check endpoint was called.")
    return "OK", 200

@app.route('/api/data', methods=['POST'])
def receive_data():
    data = request.json
    user_id = data.get('userId', 'unknown_user')
    movement_status = classify_movement(data.get('accel'))
    print(f"[INFO] ユーザーID [{user_id}] からデータ受信。状態: {movement_status['status']}")
    return jsonify({"status": "success", "received_movement": movement_status['status']})

@app.route('/api/analyze', methods=['POST'])
def analyze_data():
    print("[DEBUG] /api/analyze endpoint was called.")
    try:
        data = request.json
        sensor_history = data.get('history', [])
        print(f"[DEBUG] Received {len(sensor_history)} records for analysis.")

        if len(sensor_history) < 5:
            return jsonify({"error": "分析するにはデータが不足しています（最低5件必要です）"}), 400

        # 開発用：モックレスポンス（OpenAI APIクォータ制限回避）
        mock_response = """
        提供されたセンサーデータの履歴を分析した結果、最も可能性の高い場所トップ3およびその理由を以下に示します。

        1. 場所1: 緯度35.387418、経度139.426862
        - 確率: 70%
        - 理由: 連続して同一の位置情報が記録されており、最後の記録もこの場所である。最後の移動状態が静止状態であり、データが途切れている可能性が高い。

        2. 場所2: 緯度35.387969、経度139.427110
        - 確率: 20%
        - 理由: 位置情報の記録の中で2番目に多く、最後の移動状態も静止となっている。データの途切れた直後に記録されている。

        3. 場所3: 緯度35.388182、経度139.428562
        - 確率: 10%
        - 理由: 最初の位置情報であり、最後の移動状態は静止。データの途切れた後に再び近くで記録されている。

        これらの情報に基づいて、デバイスが最も可能性の高い場所を上記の3つとして推定します。
        """
        print("[DEBUG] Using mock response for development.")
        return jsonify({"analysis": mock_response})
    except Exception as e:
        print(f"[ERROR] An error occurred in /api/analyze: {e}")
        return jsonify({"error": f"サーバー内部でエラーが発生しました: {str(e)}"}), 500

@app.route('/api/suggest', methods=['POST'])
def get_suggestion():
    print("[DEBUG] /api/suggest endpoint was called.")
    try:
        data = request.json
        analysis_text = data.get('analysis', '')

        if not analysis_text:
            return jsonify({"error": "分析テキストが提供されていません"}), 400

        system_prompt = "あなたは効率的な探索の専門家です。"
        user_prompt = f"""
        以下のAI分析結果に基づいて、紛失したデバイスを見つけるための、具体的で実行可能なステップバイステップの探索プランを提案してください。
        ### AIによる現在の分析結果:
        {analysis_text}
        ### 提案に含めるべき要素:
        1. **最初のステップ:** まず何から始めるべきか。
        2. **探索エリアの優先順位:** どの場所から、どのような順番で探すべきか。
        3. **具体的なアクション:** 具体的な行動を指示してください。
        ユーザーがすぐに行動に移せるような、明確で簡潔な指示リストを作成してください。
        """
        
        print("[DEBUG] Calling OpenAI API for suggestion...")
        chat_completion = client.chat.completions.create(
            model="gpt-3.5-turbo", # 使用 gpt-3.5-turbo 进行测试
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ]
        )
        suggestion_text = chat_completion.choices[0].message.content
        print("[DEBUG] Successfully received suggestion from OpenAI.")
        return jsonify({"suggestion": suggestion_text})
    except Exception as e:
        print(f"[ERROR] An error occurred in /api/suggest: {e}")
        return jsonify({"error": f"サーバー内部でエラーが発生しました: {str(e)}"}), 500

@app.route('/')
def serve_index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/src/<path:filename>')
def serve_src(filename):
    return send_from_directory('src', filename)

# --- 启动服务器 ---
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000, debug=False)