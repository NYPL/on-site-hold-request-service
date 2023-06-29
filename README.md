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

In your `sam.local.yml`, set `DEVELOPMENT_LIB_ANSWERS_EMAIL` to an email you control. When `DEVELOPMENT_LIB_ANSWERS_EMAIL` is set to something, the app will direct all LibAnswers emails to this address and disable BCCs (i.e. the only outgoing emails will be sent to `DEVELOPMENT_LIB_ANSWERS_EMAIL`) This allows you to invoke the app multiple times without spamming LibAnswers or staff on BCC. You can also temporarily add this config to the QA deployment to verify the app after an update.

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

This repo follows a [Main-QA-Production Workflow](https://github.com/NYPL/engineering-general/blob/main/standards/git-workflow.md#main-qa-production)

## Testing

```
bundle exec rspec -fd
```
