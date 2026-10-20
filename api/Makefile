.PHONY: build test vet sqlc run docker

build:
	CGO_ENABLED=0 go build -trimpath -o bin/hajanek-api ./cmd/hajanek-api

test:
	go test -race ./...

vet:
	go vet ./...

sqlc:
	cd sqlc && sqlc generate && sqlc vet

run:
	ADMIN_TOKEN=$${ADMIN_TOKEN:-dev-admin} WORKER_TOKEN=$${WORKER_TOKEN:-dev-worker} \
	DB_PATH=$${DB_PATH:-bin/hajanek.db} go run ./cmd/hajanek-api

docker:
	docker buildx build --platform linux/arm64,linux/amd64 -t hajanek-api:latest .
