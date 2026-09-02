# Fantail

Worker-aware HTTP load balancing with a global admission queue.

[![Development Status](https://github.com/socketry/fantail/workflows/Test/badge.svg)](https://github.com/socketry/fantail/actions?workflow=Test)

Fantail routes each request to a worker which is ready to process it. Configurable request queues can express worker affinity and load-shedding policy while a central scheduler remains responsible for matching requests to worker permits. Fantail separates the short-lived request-processing reservation from the potentially longer response exchange, so another request can begin after response headers arrive while the previous response body is still streaming.

## Usage

Please see the [project documentation](https://socketry.github.io/fantail/) for more details.

  - [Getting Started](https://socketry.github.io/fantail/guides/getting-started/index) - This guide explains how to run Fantail and publish HTTP worker endpoints.

## Releases

Please see the [project releases](https://socketry.github.io/fantail/releases/index) for all releases.

### v0.1.0

  - Add configurable request queues, worker affinity policies, central permit scheduling, and load shedding.

### v0.0.1

  - Initial implementation.

## Contributing

We welcome contributions to this project.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` bash
$ bundle exec sus
```

### Making Releases

To make a new release:

``` bash
$ bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
