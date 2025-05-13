def xor_cipher(text: str, key: str) -> str:
    """
    Шифрует или дешифрует текст с помощью XOR-шифрования.
    
    :param text: Исходный текст для обработки
    :param key: Ключ для XOR-шифрования
    :return: Обработанный текст
    """
    # Преобразуем текст и ключ в байты
    text_bytes = text.encode('utf-8')
    key_bytes = key.encode('utf-8')
    
    # Шифруем/дешифруем каждый байт текста с помощью соответствующего байта ключа
    result_bytes = bytearray()
    for i in range(len(text_bytes)):
        result_bytes.append(text_bytes[i] ^ key_bytes[i % len(key_bytes)])
    
    return result_bytes.decode('utf-8', errors='ignore')


def main():
    print("XOR Шифровальщик/Дешифровальщик")
    print("1. Шифровать текст")
    print("2. Дешифровать текст")
    
    choice = input("Выберите действие (1/2): ")
    
    if choice not in ['1', '2']:
        print("Неверный выбор")
        return
    
    text = input("Введите текст: ")
    key = input("Введите ключ: ")
    
    if not key:
        print("Ключ не может быть пустым")
        return
    
    result = xor_cipher(text, key)
    
    if choice == '1':
        print(f"Зашифрованный текст: {result}")
    else:
        print(f"Дешифрованный текст: {result}")


if __name__ == "__main__":
    main()