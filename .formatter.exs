[
  inputs: ~w[
    {mix,.formatter}.exs
    {config,lib,test}/**/*.{ex,exs,zig}
    installer/**/*.{ex,exs}
  ],
  plugins: [Zig.Formatter]
]
