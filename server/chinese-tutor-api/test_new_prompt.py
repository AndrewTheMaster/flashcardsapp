import requests
import json
import sys

# Configuration
API_URL = "http://localhost:5000/generate"
TEST_WORDS = [
    {"word": "服务器", "hsk_level": 4, "system_language": "ru"},
    {"word": "银行", "hsk_level": 2, "system_language": "en"}
]

def test_exercise_generation():
    """Test the exercise generation API with the new prompt format"""
    print("Testing Chinese exercise generation API...\n")
    
    for test_case in TEST_WORDS:
        print(f"Testing word: {test_case['word']} (HSK {test_case['hsk_level']}, Lang: {test_case['system_language']})")
        
        try:
            response = requests.post(
                API_URL,
                json=test_case,
                timeout=60
            )
            
            # Check for successful response
            if response.status_code != 200:
                print(f"Error: API returned status code {response.status_code}")
                print(f"Response: {response.text}")
                continue
                
            # Parse response
            result = response.json()
            print("\nAPI Response:")
            print(json.dumps(result, indent=2, ensure_ascii=False))
            
            # Validate response structure
            required_fields = ["sentence_with_gap", "pinyin", "translation", "options", "answer"]
            missing_fields = [field for field in required_fields if field not in result]
            
            if missing_fields:
                print(f"\n⚠️ Warning: Response is missing the following fields: {', '.join(missing_fields)}")
            else:
                print("\n✅ All required fields are present")
                
            # Validate answer is in options
            if result.get("answer") and result.get("options"):
                if result["answer"] in result["options"]:
                    print(f"✅ Answer '{result['answer']}' is in options")
                else:
                    print(f"❌ Answer '{result['answer']}' is not in options")
            
            # Additional validation
            if len(result.get("options", [])) == 4:
                print("✅ Options count is correct (4)")
            else:
                print(f"❌ Invalid options count: {len(result.get('options', []))}, expected 4")
                
            if "____" in result.get("sentence_with_gap", ""):
                print("✅ Gap placeholder exists in sentence")
            else:
                print("❌ Gap placeholder missing in sentence")
                
        except Exception as e:
            print(f"Error during test: {str(e)}")
            
        print("\n" + "-"*50 + "\n")

if __name__ == "__main__":
    test_exercise_generation() 