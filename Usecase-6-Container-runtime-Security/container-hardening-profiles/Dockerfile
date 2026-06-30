FROM python:3.13-slim

RUN addgroup --system appgroup

RUN adduser \
--system \
--ingroup appgroup \
appuser

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir \
-r requirements.txt

COPY . .

USER appuser

EXPOSE 5000

CMD ["python","app.py"]
