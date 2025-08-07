up:
	chmod 777 -R n8n*
	docker compose up

down:
	docker compose down

format:
	pre-commit run --all-files
