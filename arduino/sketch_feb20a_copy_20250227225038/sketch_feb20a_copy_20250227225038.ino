#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_PN532.h>
#include <Wire.h>
#include <ambiente.ino>  //#define WIFI_SSID WIFI_PASSWORD


// Objeto Firebase
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Definindo os pinos SDA e SCL para o PN532 e Oled
#define PN532_SDA 21
#define PN532_SCL 22

#define OLED_RESET -1
Adafruit_SSD1306 display(OLED_RESET);
Adafruit_PN532 nfc(PN532_SDA, PN532_SCL);

// Definição das tags cadastradas
uint8_t tag1[] = { 0x8B, 0x89, 0xAE, 0x02 };
uint8_t tag2[] = { 0xB3, 0x92, 0x68, 0x10 };

// Variável para controle da leitura do AD8232
bool leitura_ativa = false;

bool alerta = false;

void setup() {
  Serial.begin(115200);
  Wire.begin();

  // Configuração do WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("[  ] - Conectando ao WiFi...");
  }
  Serial.println("[OK] - WiFi conectado!");

  // Configurações do Firebase
  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;

  // Inicializa o Firebase
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  if (!Firebase.ready()) {
    Serial.println("[FAIL] - Falha ao conectar ao Firebase!");
  } else {
    Serial.println("[OK] - Conectado ao Firebase!");
  }

    // Inicializa o display OLED
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(0, 0);
  display.print("OLED Iniciado");
  display.display();

    // Inicializa o sensor PN532
  nfc.begin();
  uint32_t versiondata = nfc.getFirmwareVersion();
  if (!versiondata) {
    Serial.println("[FAIL] - Não foi possível encontrar o PN532");
    while (1);
  }
  nfc.SAMConfig();
  Serial.println("[OK] - PN532 Iniciado");

  // Configura o pino do buzzer
  pinMode(18, OUTPUT);
  digitalWrite(18, LOW);

}

void loop() {

  if (leitura_ativa) {
    // Código para ler dados do AD8232 e exibir no OLED
    int sensorValue = analogRead(34);
    display.clearDisplay();
    display.setCursor(0, 0);
    display.print("AD8232: ");
    display.print(sensorValue);

    // Código para acionar o buzzer
    if (sensorValue > 1000) {
      digitalWrite(18, HIGH);
      alerta = true;
    } else {
      digitalWrite(18, LOW);
      alerta = false;
    }

    enviarDadosParaFirebaseAD8232(sensorValue, alerta);

    delay(500);
    display.display();
  }

  // Leitura do PN532
  uint8_t success;
  uint8_t uid[] = { 0, 0, 0, 0, 0, 0, 0 }; // Buffer para armazenar o ID da tag
  uint8_t uidLength;                      // Comprimento do buffer de ID
  
  // Verifica se há uma tag disponível
  success = nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength);
  if (success) {
    display.setCursor(0, 10);
    display.print("Tag ID: ");
    for (uint8_t i = 0; i < uidLength; i++) {
      display.print(uid[i], HEX);
      Serial.print(uid[i], HEX);
    }
    Serial.println("");

    //if (compareTag(uid, uidLength, tag1) || compareTag(uid, uidLength, tag2)) {
    if (compareTag(uid, uidLength, tag1, sizeof(tag1)) || compareTag(uid, uidLength, tag2, sizeof(tag2))) {
      leitura_ativa = !leitura_ativa; // Inverte o estado da leitura
      enviarDadosParaFirebase(uid, uidLength);
      digitalWrite(18, HIGH);
      delay(500); // Mantém o buzzer ligado por 500ms
      digitalWrite(18, LOW);
    }

    // Exibe o status da leitura
    display.setCursor(0, 20);
    display.print(leitura_ativa ? "Leitura: Ativa" : "Leitura: Inativa");
    
    display.display();
  }

  delay(1000);
}

//bool compareTag(uint8_t *tag1, uint8_t length1, uint8_t *tag2) {
  bool compareTag(uint8_t *tag1, uint8_t length1, uint8_t *tag2, uint8_t length2) {
  //if (length1 != sizeof(tag1)) {
  if (length1 != length2) {
    return false;
  }
  for (int i = 0; i < length1; i++) {
    if (tag1[i] != tag2[i]) {
      Serial.println("- Tag não cadastrada!");
      return false;
    }
  }
  Serial.println("- Tag cadastrada!");
  return true;
}

void enviarDadosParaFirebase(uint8_t *tag, uint8_t length) {
  FirebaseJson json;
  String tagStr = ""; //B3926810
  for (uint8_t i = 0; i < length; i++) {
    tagStr += String(tag[i], HEX);
  }
  json.set("tag_rfid", tagStr);
  json.set("iniciou", true);

  if (Firebase.RTDB.setJSON(&fbdo, "/drivers/-OJf_KbUSZCRGYoeZEMO/8b89ae2", &json)) {
    Serial.println("[OK] - Dados PN532 enviados!");
  } else {
    Serial.println(fbdo.errorReason());
  }
}

void enviarDadosParaFirebaseAD8232(int sensor, bool alert) {
  FirebaseJson json;
  json.set("sensor_ad8232", sensor);
  json.set("alerta", alert);

  if (Firebase.RTDB.setJSON(&fbdo, "/drivers/-OJf_KbUSZCRGYoeZEMO/8b89ae2", &json)) {
    Serial.println("[OK] - Dados AD8232 enviados!");
  } else {
    Serial.println(fbdo.errorReason());
  }
}

