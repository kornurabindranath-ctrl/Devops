from celery import Celery

app = Celery(
'worker',
broker='redis://cache:6379/0'
)

@app.task
def process():

    return "processed"
