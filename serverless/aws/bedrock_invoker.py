import boto3
import json

s3 = boto3.client('s3')
bedrock = boto3.client('bedrock-runtime', region_name = 'us-east-1')

def handler(event, context):
    # Extract text from textract json
    blocks = event['blocks']
    lines = [block['Text'] for block in blocks if block['BlockType'] == 'LINE']
    document_text = " ".join(lines)

    # Format Prompt for Llama 3.3 70B Instruct
    prompt = f"""<|begin_of_text|><|start_header_id|>system<|end_header_id|>
You are an expert document analyst. Summarize the text and determine the sentiment.<|eot_id|>
<|start_header_id|>user<|end_header_id|>
Please process the following document:
{document_text}<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>"""

    payload = {
        "prompt": prompt,
        "max_gen_len": 1024,
        "temperature": 0.5,
        "top_p": 0.9
    }

    # Invoke bedrock model
    ai_response = bedrock.invoke_model(
        modelId = 'us.meta.llama3-3-70b-instruct-v1:0',
        body = json.dumps(payload)
    )
    result_body = json.loads(ai_response.get('body').read())

    # Return the analysis result for next task to use
    return {
        "analysis_result": result_body.get('generation')
    }