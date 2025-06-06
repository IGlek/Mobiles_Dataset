import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import re
from typing import Optional, Dict, Tuple
import logging

# Настройка логирования
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MobileDataImporter:
    """Класс для импорта данных из CSV в PostgreSQL с нормализацией"""
    
    def __init__(self, db_config: Dict[str, str]):
        """
        Инициализация импортера
        
        Args:
            db_config: Словарь с параметрами подключения к БД
        """
        self.db_config = db_config
        self.conn = None
        self.cursor = None
        self.company_cache = {}
        self.processor_cache = {}
        self.region_cache = {}
    
    def connect(self):
        """Установка соединения с БД"""
        try:
            self.conn = psycopg2.connect(**self.db_config)
            self.cursor = self.conn.cursor()
            logger.info("✅ Успешное подключение к БД")
        except Exception as e:
            logger.error(f"❌ Ошибка подключения к БД: {e}")
            raise
    
    def disconnect(self):
        """Закрытие соединения с БД"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        logger.info("🔒 Соединение с БД закрыто")
    
    def parse_price(self, price_str: str) -> Optional[float]:
        """
        Парсинг строки с ценой
        
        Args:
            price_str: Строка с ценой (может содержать символы валюты)
            
        Returns:
            Числовое значение цены или None
        """
        if pd.isna(price_str) or price_str == '':
            return None
        
        # Удаляем все символы кроме цифр и точки
        price_str = str(price_str)
        price_clean = re.sub(r'[^\d.]', '', price_str)
        
        try:
            return float(price_clean) if price_clean else None
        except ValueError:
            logger.warning(f"⚠️ Не удалось распарсить цену: {price_str}")
            return None
    
    def get_or_create_company(self, company_name: str) -> int:
        """Получение или создание компании"""
        if company_name in self.company_cache:
            return self.company_cache[company_name]
        
        # Проверяем существование
        self.cursor.execute(
            "SELECT company_id FROM companies WHERE company_name = %s",
            (company_name,)
        )
        result = self.cursor.fetchone()
        
        if result:
            company_id = result[0]
        else:
            # Создаем новую компанию
            self.cursor.execute(
                "INSERT INTO companies (company_name) VALUES (%s) RETURNING company_id",
                (company_name,)
            )
            company_id = self.cursor.fetchone()[0]
            logger.info(f"➕ Добавлена компания: {company_name}")
        
        self.company_cache[company_name] = company_id
        return company_id
    
    def get_or_create_processor(self, processor_name: str) -> Optional[int]:
        """Получение или создание процессора"""
        if pd.isna(processor_name) or processor_name == '':
            return None
            
        if processor_name in self.processor_cache:
            return self.processor_cache[processor_name]
        
        # Проверяем существование
        self.cursor.execute(
            "SELECT processor_id FROM processors WHERE processor_name = %s",
            (processor_name,)
        )
        result = self.cursor.fetchone()
        
        if result:
            processor_id = result[0]
        else:
            # Создаем новый процессор
            self.cursor.execute(
                "INSERT INTO processors (processor_name) VALUES (%s) RETURNING processor_id",
                (processor_name,)
            )
            processor_id = self.cursor.fetchone()[0]
            logger.info(f"➕ Добавлен процессор: {processor_name}")
        
        self.processor_cache[processor_name] = processor_id
        return processor_id
    
    def load_regions(self):
        """Загрузка регионов в кэш"""
        self.cursor.execute("SELECT region_id, region_name FROM regions")
        for region_id, region_name in self.cursor.fetchall():
            self.region_cache[region_name] = region_id
        logger.info(f"📍 Загружено регионов: {len(self.region_cache)}")
    
    def import_data(self, csv_path: str):
        """
        Основной метод импорта данных
        
        Args:
            csv_path: Путь к CSV файлу
        """
        logger.info(f"📂 Начинаем импорт из файла: {csv_path}")
        
        # Читаем CSV
        df = pd.read_csv(csv_path, encoding='cp1252')
        logger.info(f"📊 Загружено строк: {len(df)}")
        
        # Загружаем регионы
        self.load_regions()
        
        # Обрабатываем каждую строку
        models_count = 0
        prices_count = 0
        
        for idx, row in df.iterrows():
            try:
                # Получаем или создаем компанию
                company_id = self.get_or_create_company(row['Company Name'])
                
                # Получаем или создаем процессор
                processor_id = self.get_or_create_processor(row['Processor'])
                
                # Проверяем существование модели
                self.cursor.execute(
                    """SELECT model_id FROM models 
                       WHERE model_name = %s AND company_id = %s""",
                    (row['Model Name'], company_id)
                )
                existing_model = self.cursor.fetchone()
                
                if existing_model:
                    model_id = existing_model[0]
                else:
                    # Вставляем модель
                    self.cursor.execute(
                        """INSERT INTO models 
                           (model_name, company_id, processor_id, mobile_weight, 
                            ram, front_camera, back_camera, battery_capacity, 
                            screen_size, launched_year)
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                           RETURNING model_id""",
                        (
                            row['Model Name'],
                            company_id,
                            processor_id,
                            row['Mobile Weight'] if pd.notna(row['Mobile Weight']) else None,
                            row['RAM'] if pd.notna(row['RAM']) else None,
                            row['Front Camera'] if pd.notna(row['Front Camera']) else None,
                            row['Back Camera'] if pd.notna(row['Back Camera']) else None,
                            row['Battery Capacity'] if pd.notna(row['Battery Capacity']) else None,
                            row['Screen Size'] if pd.notna(row['Screen Size']) else None,
                            int(row['Launched Year']) if pd.notna(row['Launched Year']) else None
                        )
                    )
                    model_id = self.cursor.fetchone()[0]
                    models_count += 1
                
                # Вставляем цены для всех регионов
                price_columns = [
                    ('Pakistan', 'Launched Price (Pakistan)'),
                    ('India', 'Launched Price (India)'),
                    ('China', 'Launched Price (China)'),
                    ('USA', 'Launched Price (USA)'),
                    ('Dubai', 'Launched Price (Dubai)')
                ]
                
                for region_name, price_column in price_columns:
                    price = self.parse_price(row[price_column])
                    if price is not None:
                        region_id = self.region_cache[region_name]
                        
                        # Проверяем существование цены
                        self.cursor.execute(
                            """SELECT price_id FROM prices 
                               WHERE model_id = %s AND region_id = %s""",
                            (model_id, region_id)
                        )
                        
                        if not self.cursor.fetchone():
                            self.cursor.execute(
                                """INSERT INTO prices (model_id, region_id, price)
                                   VALUES (%s, %s, %s)""",
                                (model_id, region_id, price)
                            )
                            prices_count += 1
                
                # Коммитим каждые 100 записей
                if (idx + 1) % 100 == 0:
                    self.conn.commit()
                    logger.info(f"💾 Обработано строк: {idx + 1}")
                    
            except Exception as e:
                logger.error(f"❌ Ошибка при обработке строки {idx}: {e}")
                self.conn.rollback()
                continue
        
        # Финальный коммит
        self.conn.commit()
        logger.info(f"""
        ✅ Импорт завершен успешно!
        📱 Добавлено моделей: {models_count}
        💰 Добавлено цен: {prices_count}
        🏢 Компаний в БД: {len(self.company_cache)}
        🔧 Процессоров в БД: {len(self.processor_cache)}
        """)


# Использование скрипта
if __name__ == "__main__":
    # Конфигурация подключения к БД
    db_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'mobile_devices_db',
        'user': 'admin',
        'password': 'password'  # Замените на ваш пароль
    }
    
    # Создаем импортер и выполняем импорт
    importer = MobileDataImporter(db_config)
    
    try:
        importer.connect()
        importer.import_data('Mobiles Dataset 2025.csv')  # Укажите путь к вашему файлу
    finally:
        importer.disconnect()