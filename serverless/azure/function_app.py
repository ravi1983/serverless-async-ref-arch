import os
import json
import logging

import azure.functions as func
from openai import AzureOpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="summarize", methods=["POST"])
def func_app_handler(req: func.HttpRequest) -> func.HttpResponse:
    try:
        req_body = req.get_json()
        text_to_analyze = req_body.get('text')

        openai_url = os.environ.get('AZURE_OPENAI_ENDPOINT')
        logging.info(f"OpenAI URL: {openai_url}")

        client = AzureOpenAI(
            azure_endpoint=openai_url,
            api_key=os.environ.get('AZURE_OPENAI_KEY'),
            api_version="2024-02-15-preview"
        )

        response = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {"role": "system", "content": "You are an assistant that provides a brief summary and sentiment analysis (Positive/Negative/Neutral)."},
                {"role": "user", "content": f"Analyze this text: {text_to_analyze}"}
            ]
        )

        return func.HttpResponse(
            json.dumps({
                "summary": response.choices[0].message.content,
                "status": "success"
            }),
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Error: {e}")
        return func.HttpResponse(f"Error: {e}")