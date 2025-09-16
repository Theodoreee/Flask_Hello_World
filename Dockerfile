FROM python:3.9-slim

WORKDIR /Flask_Hello_World

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "__init__.py"]
