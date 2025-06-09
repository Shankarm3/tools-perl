from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import requests

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ GET method to check server status
@app.get("/ping")
async def ping():
    return {"status": "ok", "message": "Server is running"}

# POST method for chat
@app.post("/chat")
async def chat(request: Request):
    try:
        data = await request.json()
        prompt = data.get("prompt", "")

        response = requests.post("http://localhost:11434/api/generate", json={
            "model": "llama3:latest",
            "prompt": prompt,
            "stream": False,
            "options": {
                "num_predict": 50
            }
        })

        result = response.json()
        return {"response": result.get("response", "").strip()}

    except requests.exceptions.RequestException as e:
        return {"error": f"API call failed: {str(e)}"}
    except Exception as e:
        return {"error": str(e)}
