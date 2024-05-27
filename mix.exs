# Copyright 2024 Clivern. All rights reserved.
# Use of this source code is governed by the MIT
# license that can be found in the LICENSE file.

defmodule Oak.MixProject do
  use Mix.Project

  @version "0.1.0"
  @url_docs "http://hexdocs.pm/oak"
  @url_github "https://github.com/clivern/oak"

  def project do
    [
      app: :oak,
      name: "Oak",
      description: "Elixir Prometheus Exporter",
      package: %{
        files: [
          "lib",
          "mix.exs",
          "LICENSE"
        ],
        licenses: ["MIT"],
        links: %{
          "Docs" => @url_docs,
          "GitHub" => @url_github
        },
        maintainers: ["Clivern"]
      },
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      compilers: [] ++ Mix.compilers(),
      deps: deps(),
      docs: [
        source_ref: "v#{@version}",
        source_url: @url_github,
        main: "Oak",
        extras: ["README.md"]
      ],
      preferred_cli_env: [
        docs: :docs
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev], runtime: false}
    ]
  end
end
