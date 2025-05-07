# coding: utf-8
import os
import torch
from transformers import BertTokenizer, BertForMaskedLM

def test_bert_wwm():
    """Test that the Chinese BERT-WWM model is working properly."""
    print("Testing Chinese BERT-WWM model...")
    
    # Check if model is available locally
    model_dir = "chinese-bert-wwm"
    if os.path.exists(model_dir) and os.path.isdir(model_dir):
        try:
            print(f"Loading model from local directory: {model_dir}")
            tokenizer = BertTokenizer.from_pretrained(model_dir)
            model = BertForMaskedLM.from_pretrained(model_dir)
            source = "local"
        except Exception as e:
            print(f"Error loading from local directory: {e}")
            print("Trying to load from Hugging Face...")
            tokenizer = BertTokenizer.from_pretrained("hfl/chinese-bert-wwm")
            model = BertForMaskedLM.from_pretrained("hfl/chinese-bert-wwm")
            source = "huggingface"
    else:
        print(f"Local model directory not found: {model_dir}")
        print("Loading model from Hugging Face...")
        tokenizer = BertTokenizer.from_pretrained("hfl/chinese-bert-wwm")
        model = BertForMaskedLM.from_pretrained("hfl/chinese-bert-wwm")
        source = "huggingface"
    
    print(f"Model loaded successfully from {source}!")
    
    # Set device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    model.to(device)
    
    # Test with a simple example
    test_text = "今天天气[MASK]好。"
    print(f"\nTest sentence: {test_text}")
    
    # Tokenize
    inputs = tokenizer(test_text, return_tensors="pt").to(device)
    
    # Find mask token index
    mask_token_index = torch.where(inputs["input_ids"][0] == tokenizer.mask_token_id)[0]
    
    # Forward pass
    with torch.no_grad():
        outputs = model(**inputs)
    
    # Get predictions
    logits = outputs.logits
    mask_token_logits = logits[0, mask_token_index, :]
    top_5_tokens = torch.topk(mask_token_logits, 5, dim=1).indices[0].tolist()
    
    # Convert token IDs to words
    top_5_words = [tokenizer.decode([token_id]) for token_id in top_5_tokens]
    
    # Print results
    print("Top 5 predictions for [MASK]:")
    for i, word in enumerate(top_5_words, 1):
        print(f"  {i}. {word}")
    
    print("\nTest completed successfully!")
    return True

if __name__ == "__main__":
    test_bert_wwm() 