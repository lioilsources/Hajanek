.PHONY: e2e test vet api-test forge-test app-test judge forge smoke ambient app-run api-run

test: api-test forge-test app-test judge

vet:
	cd api && go vet ./...
	cd forge && go vet ./...

api-test:
	cd api && go vet ./... && go test ./...

forge-test:
	cd forge && go vet ./... && go test ./...

app-test:
	cd app && flutter analyze && flutter test

forge:
	cd forge && go build -o bin/forge ./cmd/forge

# Deterministic judge over every script in content/.
judge: forge
	@for f in content/scripts/*.md content/scripts/gold/*.md; do \
		printf "%-50s " "$$f"; \
		forge/bin/forge judge --no-llm --content content "$$f" > /dev/null && echo PASS || { echo FAIL; exit 1; }; \
	done

# judge → ambient loop → publish into a throwaway pages dir, validate catalog.json.
smoke:
	cd forge && ./testdata/smoke.sh

# Parent-voice flow end to end: api + forge worker + fake audio service.
e2e:
	./tools/e2e/voice_e2e.sh

ambient:
	cd content/ambient && ./make_loops.sh

api-run:
	$(MAKE) -C api run

app-run:
	cd app && flutter run
