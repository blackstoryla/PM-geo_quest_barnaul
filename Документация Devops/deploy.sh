#!/bin/bash

# Проверка, что Ansible установлен
if ! command -v ansible &> /dev/null; then
    echo "Ansible не установлен. Устанавливаем..."
    sudo apt update
    sudo apt install -y ansible
fi

# Создание Ansible-инвентаря (inventory.ini)
cat <<EOF > inventory.ini
[web]
server_ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/private_key.pem

[db]
db_ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/private_key.pem
EOF

# Создание Ansible-плейбука (deploy.yml)
cat <<EOF > deploy.yml
---
- name: Deploy Geo Quest Barnaul
  hosts: web
  become: yes

  tasks:
    - name: Обновить apt-кеш
      apt:
        update_cache: yes

    - name: Установить зависимости
      apt:
        name:
          - docker.io
          - docker-compose
          - nginx
          - python3-pip
        state: present

    - name: Запустить Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Клонировать репозиторий
      git:
        repo: https://github.com/geoquest-barnaul.git
        dest: /opt/geoquest
        version: main

    - name: Создать .env файл
      copy:
        dest: /opt/geoquest/.env
        content: |
          DB_HOST=db_ip
          DB_USER=user
          DB_PASS=password
          MAPS_API_KEY=yandex_maps_key

    - name: Запустить приложение через Docker Compose
      command: docker-compose up -d
      args:
        chdir: /opt/geoquest

    - name: Настроить Nginx как прокси
      copy:
        dest: /etc/nginx/sites-available/geoguessr
        content: |
          server {
              listen 80;
              server_name domain.com;
              location / {
                  proxy_pass http://localhost:3000;
                  proxy_set_header Host \$host;
              }
          }
      notify:
        - Перезапустить Nginx

  handlers:
    - name: Перезапустить Nginx
      service:
        name: nginx
        state: restarted
EOF

# Запуск Ansible-плейбука
ansible-playbook -i inventory.ini deploy.yml

echo "Развертывание завершено! Приложение доступно на http://server_ip"