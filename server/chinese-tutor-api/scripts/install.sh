#!/bin/bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "Загрузка моделей BERT..."
python3 -c "
from transformers import BertForMaskedLM, BertTokenizer;
BertForMaskedLM.from_pretrained('bert-base-chinese');
BertTokenizer.from_pretrained('bert-base-chinese');
print('Модели загружены!')
"

flask --app app/main run --host=0.0.0.0 --port=5000 