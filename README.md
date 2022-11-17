# On Site Hold Request Service

## Purpose

This is an internal service for creating holds for "on-site" items in Sierra. Supports on-site EDD requests.

* `POST /api/v0.1/on-site-hold-requests`: Creates hold request in Sierra, queues EDD job
* `GET /docs/on-site-hold-requests`: Gets swagger partial describing the endpoint

See [Swagger](./swagger.json) for full [OAI 2.0](https://swagger.io/specification/v2/) specification.

## Running locally

```
rvm use
bundle install
```

Create your own `sam.local.yml`:
```
cp sam.example.yml sam.local.yml
```

In your `sam.local.yml`, set `DEVELOPMENT_LIB_ANSWERS_EMAIL` to an email you control. When `APP_ENV` is _anything_ other than 'production' (e.g. "development"), the app will only send emails to `DEVELOPMENT_LIB_ANSWERS_EMAIL`. This allows you to invoke the app multiple times without spamming LibAnswers.

To run a local server against Sierra Test:

```
sam local start-api --region us-east-1 --template sam.local.yml --profile nypl-digital-dev
```

To run a specific query, choose an event in `./events` and run, for example:

```
sam local invoke --region us-east-1 --template sam.local.yml --profile nypl-digital-dev --event events/create-edd-hold-request-sasb.json
```

Note that the invocation will fail if there's already a hold on the item. Manually delete the hold using the Sierra API (i.e. in Postman) to re-run the event.

## Contributing

This repo follows a [Development-QA-Master Git Workflow](https://github.com/NYPL/engineering-general/blob/a19c78b028148465139799f09732e7eb10115eef/standards/git-workflow.md#development-qa-master)

## Testing

```
bundle exec rspec -fd
```
