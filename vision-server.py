import http.server
import json
import socketserver
import threading

from PIL import Image
from transformers import AutoModelForCausalLM, AutoProcessor

PORT = 8000
model_id = "microsoft/Phi-3-vision-128k-instruct"

model = AutoModelForCausalLM.from_pretrained(model_id, device_map="cuda", trust_remote_code=True, torch_dtype="auto",
                                             _attn_implementation='flash_attention_2')
processor = AutoProcessor.from_pretrained(model_id, trust_remote_code=True)
messages = [
    {"role": "user",
     "content": "<|image_1|>\n"
                "Return main keywords/categories useful for indexing this image in a comma-separated format. "
                "Only output the list, nothing else."}
]
generation_args = {
    "max_new_tokens": 512,
    "temperature": 0.0,
    "do_sample": False,
}
prompt = processor.tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)


def cut_at_repeating_item(input_string):
    items = input_string.split(',')
    seen = set()

    for i, item in enumerate(items):
        item = item.lower()
        if item in seen:
            return ','.join(seen)
        seen.add(item)

    return input_string.lower()

process_lock = threading.Lock()
class ServerHandler(http.server.SimpleHTTPRequestHandler):

    def _set_headers(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)

        # Extracting image path from JSON
        data = json.loads(post_data.decode('utf-8'))
        image_path = data['image_path']
        print("Opening " + image_path)
        try:
            image = Image.open(image_path)
        except Exception as e:
            print("Error when reading " + image_path)
            self._set_headers()
            self.wfile.write(json.dumps({'error': 'Error: ' + repr(e)}).encode('utf-8'))
            return
        inputs = processor(prompt, [image], return_tensors="pt").to("cuda:0")
        with process_lock:
            generate_ids = model.generate(**inputs, eos_token_id=processor.tokenizer.eos_token_id, **generation_args)
        generate_ids = generate_ids[:, inputs['input_ids'].shape[1]:]  # remove input tokens
        response = processor.batch_decode(generate_ids, skip_special_tokens=True, clean_up_tokenization_spaces=False)[0]
        response = cut_at_repeating_item(response)
        print(image_path +": " + response)

        self._set_headers()
        self.wfile.write(json.dumps({'response': response}).encode('utf-8'))


def run(server_class=socketserver.ThreadingTCPServer, handler_class=ServerHandler):
    server_address = ('', PORT)
    httpd = server_class(server_address, handler_class)
    print(f"Starting httpd server on {PORT}")
    httpd.serve_forever()


if __name__ == "__main__":
    run()
