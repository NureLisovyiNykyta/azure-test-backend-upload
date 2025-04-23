from flask import Flask
from flask_sqlalchemy import SQLAlchemy
import os

app = Flask(__name__)

# Настройка подключения к базе данных из переменной окружения
db_uri = os.environ.get('POSTGRES_CONNECTION')
if not db_uri:
    raise ValueError("POSTGRES_CONNECTION environment variable not set")
app.config['SQLALCHEMY_DATABASE_URI'] = db_uri
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Тестовая модель для проверки
class Test(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50))

# Маршрут для проверки подключения
@app.route('/')
def check_db():
    try:
        # Создаём таблицу, если она не существует
        with app.app_context():
            db.create_all()
        # Проверяем подключение простым запросом
        count = Test.query.count()
        return f"Database connection successful. Records in Test table: {count}", 200
    except Exception as e:
        return f"Database connection failed: {str(e)}", 500

@app.route('/run-script')
def run_script():
    from sqlalchemy import text

    try:
        with open("init_db.sql", "r", encoding="utf-8") as f:
            sql_script = f.read()

        with db.engine.connect() as connection:
            connection.execute(text(sql_script))
        return "Database initialized via endpoint", 200
    except Exception as e:
        return f"Failed to run SQL script: {str(e)}", 500


if __name__ == '__main__':
    app.run(debug=True)