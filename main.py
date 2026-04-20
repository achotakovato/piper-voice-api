import os, io, json, subprocess, tempfile
from pathlib import Path
from fastapi import FastAPI, UploadFile, Form, HTTPException
from fastapi.responses import Response
from vosk import Model, KaldiRecognizer

app = FastAPI(title="Piper+Vosk Voice API")

MODELS_DIR = Path("/app/models")
TTS_MODEL = MODELS_DIR / "ru_RU-dmitri-medium.onnx"
TTS_CONFIG = MODELS_DIR / "ru_RU-dmitri-medium.onnx.json"
STT_MODEL = MODELS_DIR / "vosk-model-small-ru-0.22"

stt_model = None

@app.on_event("startup")
def load_stt():
    global stt_model
    if STT_MODEL.exists():
        stt_model = Model(str(STT_MODEL))
        print(f"✅ STT loaded: {STT_MODEL}")

@app.post("/tts")
def text_to_speech(text: str = Form(...)):
    if not TTS_MODEL.exists():
        raise HTTPException(503, "TTS model not found")
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp_path = tmp.name
        subprocess.run([
            "piper", "--model", str(TTS_MODEL), "--config", str(TTS_CONFIG),
            "--output_file", tmp_path, "--sentence_silence", "0.2"
        ], input=text.encode("utf-8"), capture_output=True, check=True)
        with open(tmp_path, "rb") as f:
            audio = f.read()
        os.unlink(tmp_path)
        return Response(content=audio, media_type="audio/wav")
    except subprocess.CalledProcessError as e:
        raise HTTPException(500, f"Piper error: {e.stderr.decode() if e.stderr else str(e)}")
    except Exception as e:
        raise HTTPException(500, f"TTS error: {str(e)}")

@app.post("/stt")
async def speech_to_text(file: UploadFile):
    if stt_model is None:
        raise HTTPException(503, "STT model not loaded")
    try:
        audio_bytes = await file.read()
        rec = KaldiRecognizer(stt_model, 16000)
        rec.AcceptWaveform(audio_bytes)
        result = json.loads(rec.FinalResult())
        return {"text": result.get("text", "")}
    except Exception as e:
        raise HTTPException(500, f"STT error: {str(e)}")

@app.get("/health")
def health_check():
    return {"status": "ok", "tts": TTS_MODEL.exists(), "stt": stt_model is not None}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
