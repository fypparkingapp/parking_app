# Landmarks API (Docker Deploy)

This folder provides a deployable API server for:

- `assets/data/local_landmarks/*.json`

The API serves full records, category/subcategory filters, and text search.

## Run with Docker

From project root:

```bash
docker build -t hk-landmarks-api -f deploy/landmarks_api/Dockerfile .
docker run --rm -p 8080:8080 hk-landmarks-api
```

API base URL:

- `http://localhost:8080`
- Swagger docs: `http://localhost:8080/docs`

## Run with Docker Compose

From project root:

```bash
docker compose -f deploy/landmarks_api/docker-compose.yml up --build
```

## Endpoints

- `GET /health`
- `GET /v1/meta`
- `GET /v1/categories`
- `GET /v1/landmarks?limit=100&offset=0`
- `GET /v1/landmarks?category=cultureLeisure`
- `GET /v1/landmarks?subcategory=mall`
- `GET /v1/landmarks/search?q=symphony` (uses map.gov.hk locationSearch)
- `GET /v1/landmarks/search?q=朗峰園`
- `GET /v1/landmarks/search/local?q=centre&category=cultureLeisure&subcategory=majorDestination`
- `POST /v1/admin/reload`

## Query Parameters

- `q`: keyword for search endpoints
- `category`: exact match filter
- `subcategory`: exact match filter
- `limit`: page size (`1..MAX_LIMIT`)
- `offset`: pagination offset (`>=0`)

`/v1/landmarks/search` proxies `https://www.map.gov.hk/gs/api/v1.0.0/locationSearch?q=...`.
`/v1/landmarks/search/local` uses local JSON dataset filtering.

## Environment Variables

- `LANDMARKS_DIR` default: `/app/data/local_landmarks`
- `DEFAULT_LIMIT` default: `50`
- `MAX_LIMIT` default: `5000`
- `MAP_GOV_LOCATION_SEARCH_URL` default: `https://www.map.gov.hk/gs/api/v1.0.0/locationSearch`
- `MAP_GOV_REFERER` default: `https://www.map.gov.hk/`
- `UPSTREAM_TIMEOUT_SECONDS` default: `10`
