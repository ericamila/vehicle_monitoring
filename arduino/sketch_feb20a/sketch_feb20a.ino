#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>
#include <Wire.h>
#include <MPU6050.h>
#include <ambiente.ino>  //#define WIFI_SSID WIFI_PASSWORD


// Objeto Firebase
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// GPS
HardwareSerial gpsSerial(1);
TinyGPSPlus gps;

// MPU6050
MPU6050 mpu;
bool emMovimento = false;

void setup() {
  Serial.begin(115200);
  gpsSerial.begin(9600, SERIAL_8N1, 16, 17);  // RX=16, TX=17 para GPS

  // Configuração do WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Conectando ao WiFi...");
  }
  Serial.println("WiFi conectado!");
  Serial.println(" v1 ");

  // Configurações do Firebase
  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  // Inicializa o Firebase
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  if (!Firebase.ready()) {
    Serial.println("Falha ao conectar ao Firebase!");
  } else {
    Serial.println("Conectado ao Firebase!");
  }

  // Inicializar MPU6050
  Wire.begin();
  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println("Falha ao conectar ao MPU6050");
    while (1);
  }
}

void loop() {
  /*
  // Capturar dados do GPS
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  if (gps.location.isUpdated()) {
    float latitude = gps.location.lat();
    float longitude = gps.location.lng();
    
    // Detectar movimento com MPU6050
    int16_t ax, ay, az;
    mpu.getAcceleration(&ax, &ay, &az);
    emMovimento = (abs(ax) > 5000 || abs(ay) > 5000 || abs(az) > 5000);

    // Enviar para o Firebase
    FirebaseJson json;
    json.set("latitude", latitude);
    json.set("longitude", longitude);
    json.set("em_movimento", emMovimento);

    if (Firebase.RTDB.setJSON(&fbdo, "/vehicles/veiculo1", &json)) {
      Serial.println("Dados enviados!");
    } else {
      Serial.println(fbdo.errorReason());
    }
  }

  delay(5000);
  */

// TESTE
    if (1==1) {

    // Enviar para o Firebase
    FirebaseJson json;
    json.set("latitude", 2.8360178);
    json.set("longitude", -60.709525);
    json.set("em_movimento", true);
    json.set("velocidade", 45);

    if (Firebase.RTDB.setJSON(&fbdo, "/vehicles/veiculo2", &json)) {
      Serial.println("Dados enviados!");
    } else {
      Serial.println(fbdo.errorReason());
    }
  }

  delay(10000);
}
