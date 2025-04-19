from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
from transformers import BertTokenizer, BertForSequenceClassification
import uvicorn

app = FastAPI(title="BERT REST API")

# Загрузка модели и токенизатора
model_path = "./my_bert_model"
tokenizer = BertTokenizer.from_pretrained(model_path)
model = BertForSequenceClassification.from_pretrained(model_path)
model.eval()  # Переводим модель в режим оценки

class PredictionRequest(BaseModel):
    text: str

class PredictionResponse(BaseModel):
    label: int
    confidence: float

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    try:
        # Токенизация входного текста
        inputs = tokenizer(request.text, return_tensors="pt", padding=True, truncation=True, max_length=512)
        
        # Получение предсказания
        with torch.no_grad():
            outputs = model(**inputs)
            predictions = outputs.logits
            
        # Обработка предсказаний
        probabilities = torch.nn.functional.softmax(predictions, dim=-1)
        confidence, predicted_class = torch.max(probabilities, dim=-1)
        
        return {
            "label": predicted_class.item(),
            "confidence": confidence.item()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    return {"message": "BERT API is running!"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 