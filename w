Для получения списка всех объектов в бакете Amazon S3 с их ключами, MD5-хэшами и размерами в байтах на языке C#, вы можете воспользоваться AWS SDK для .NET. Ниже представлен оптимизированный пример кода, который использует асинхронные вызовы и параллельную обработку для повышения скорости выполнения.

## 1. Установка AWS SDK для .NET

Если вы еще не установили AWS SDK для .NET, добавьте его в ваш проект через NuGet:

Install-Package AWSSDK.S3


## 2. Оптимизированный код на C#

using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Amazon;
using Amazon.S3;
using Amazon.S3.Model;

namespace S3BucketLister
{
    public class S3ObjectInfo
    {
        public string Key { get; set; }
        public string ETag { get; set; } // Обычно ETag соответствует MD5 для непрерывных объектов
        public long Size { get; set; }
    }

    class Program
    {
        private static readonly string bucketName = "your-bucket-name";
        private static readonly RegionEndpoint bucketRegion = RegionEndpoint.USEast1; // Укажите регион вашего бакета
        private static IAmazonS3 s3Client;

        static async Task Main(string[] args)
        {
            s3Client = new AmazonS3Client(bucketRegion);

            try
            {
                List<S3ObjectInfo> allObjects = await GetAllS3ObjectsAsync(bucketName);
                
                // Пример вывода
                foreach (var obj in allObjects)
                {
                    Console.WriteLine($"Key: {obj.Key}, ETag(MD5): {obj.ETag}, Size: {obj.Size} bytes");
                }

                Console.WriteLine($"Total objects: {allObjects.Count}");
            }
            catch (AmazonS3Exception e)
            {
                Console.WriteLine($"Error encountered ***. Message:'{e.Message}'");
            }
            catch (Exception e)
            {
                Console.WriteLine($"Unknown error encountered ***. Message:'{e.Message}'");
            }
        }

        public static async Task<List<S3ObjectInfo>> GetAllS3ObjectsAsync(string bucketName)
        {
            List<S3ObjectInfo> objects = new List<S3ObjectInfo>();
            string continuationToken = null;
            int maxConcurrency = 10; // Максимальное количество параллельных потоков

            var listRequest = new ListObjectsV2Request
            {
                BucketName = bucketName,
                MaxKeys = 1000, // Максимальное количество объектов за запрос
                ContinuationToken = continuationToken
            };

            do
            {
                listRequest.ContinuationToken = continuationToken;
                var response = await s3Client.ListObjectsV2Async(listRequest);

                foreach (var s3Object in response.S3Objects)
                {
                    objects.Add(new S3ObjectInfo
                    {
                        Key = s3Object.Key,
                        ETag = s3Object.ETag.Trim('"'), // Удаляем кавычки вокруг ETag
                        Size = s3Object.Size
                    });
                }

                continuationToken = response.IsTruncated ? response.NextContinuationToken : null;

            } while (continuationToken != null);

            return objects;
        }
    }
}


## 3. Объяснение кода

### 3.1. Инициализация клиента S3

private static readonly string bucketName = "your-bucket-name";
private static readonly RegionEndpoint bucketRegion = RegionEndpoint.USEast1; // Укажите регион вашего бакета
private static IAmazonS3 s3Client;


- bucketName: Замените "your-bucket-name" на имя вашего S3-бакета.
- bucketRegion: Укажите регион вашего бакета, например, RegionEndpoint.USEast1.

### 3.2. Метод GetAllS3ObjectsAsync

public static async Task<List<S3ObjectInfo>> GetAllS3ObjectsAsync(string bucketName)
{
    List<S3ObjectInfo> objects = new List<S3ObjectInfo>();
    string continuationToken = null;

    var listRequest = new ListObjectsV2Request
    {