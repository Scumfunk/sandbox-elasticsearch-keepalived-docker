# Песочница для тестирования Elasticsearch + keepalived

## Сборка и запуск

```
# Для работы keepalived в docker нужно сделать следующее
sudo sysctl net.ipv4.ip_nonlocal_bind=1

# Создаем виртуальную сеть docker, чтобы можно было задать статичные ip
docker network create --subnet=172.18.0.0/16 mynet123

# Собираем образы
cd docker
docker build -t es1 --build-arg NAME=es1 .
docker build -t es2 --build-arg NAME=es2 .
docker build -t es3 --build-arg NAME=es3 .

# Для нормальной работы ES необходимо повысить vm.max_map_count
sudo sysctl -w vm.max_map_count=262144

# Запускаем с --cap-add=NET_ADMIN
docker run -d --net mynet123 --cap-add=NET_ADMIN --ip 172.18.0.101 --name es1 es1
docker run -d --net mynet123 --cap-add=NET_ADMIN --ip 172.18.0.102 --name es2 es2
docker run -d --net mynet123 --cap-add=NET_ADMIN --ip 172.18.0.103 --name es3 es3
```

## Проверка работы
```
curl -XGET 'http://172.18.0.100:9200/_cluster/state?pretty'
```

## Сценарии тестирования отказоустойчивости

### Падение одного текущего мастера

1. Выясняем кто сейчас мастер
    ```
    curl -XGET 'http://172.18.0.100:9200/_cluster/state?pretty'
    ```
2. Останавливаем контейнер мастера
    ```
    docker stop [es1|es2|es3]
    ```
3. Смотрим что все хорошо
    ```
    curl -XGET 'http://172.18.0.100:9200/_cluster/state?pretty'
    ```

### Падение двух мастеров из трех

1. Выясняем кто сейчас мастер
    ```
    curl -XGET 'http://172.18.0.100:9200/_cluster/state?pretty'
    ```
2. Останавливаем контейнер мастера и следом еще один
    ```
    docker stop [es1|es2|es3] # x2
    ```
3. Смотрим что получится
    ```json
    {
      "error" : {
        "root_cause" : [
          {
            "type" : "master_not_discovered_exception",
            "reason" : null
          }
        ],
        "type" : "master_not_discovered_exception",
        "reason" : null
      },
      "status" : 503
    }
    ```
    Так получается потому, что мы указали ```discovery.zen.minimum_master_nodes: 2```. Если указать 1, то на трех нодах может случиться "Split Brain".

### Возврат ноды в кластер

1. Включаем выключенную ноду
    ```
    docker start [es1|es2|es3]
    ```
2. Смотрим что все хорошо
    ```
    curl -XGET 'http://172.18.0.100:9200/_cluster/state?pretty'
    ```

### Репликация индекса

1. Поднимаем 2 ноды (X и Y), создаем индекс, заполняем чем-нибудь. Указываем при создании индекса repllicas_count = 1
2. Смотрим, что индекс на месте
    ```
    curl -XGET 'http://172.18.0.100:9200/INDEX_NAME/_stats'
    ```
3. Реплицируем индекс еще на одну ноду
    ```
    curl -X PUT "localhost:9200/INDEX_NAME/_settings" -H 'Content-Type: application/json' -d'
    {
        "index" : {
            "number_of_replicas" : 2
        }
    }
    '

    ```
    Видим ```{"acknowledged":true}```
4. Проверяем, что реплика создана
    ```
    curl -XGET 'http://172.18.0.100:9200/INDEX_NAME/_shard_stores?pretty'
    ```
    Видим, что шарда реплицирована на разные ноды
    
5. Останавливаем ту ноду, которая в реплике хотя бы одной шарды была primary (пусть она будет X)
    ```
    docker stop [es1|es2|es3]
    ```
    и вводим другую ноду (Z) в строй (помним, что на одной ноде у нас ничего не работает)
    ```
    docker start [es1|es2|es3]
    ```
6. Проверяем, что индекс на месте и реплицирован на две живые ноды (Z и Y)
    ```
    curl -XGET 'http://172.18.0.100:9200/INDEX_NAME/_shard_stores?pretty'
    ```
    видим, что одна из нод X, Z - primary
7. (Для спокойствия души) Проверяем поиск
    ```
    curl -XGET 'http://172.18.0.100:9200/INDEX_NAME/_search?q=*&pretty'
    ```

## Описание настроек ES

TODO

