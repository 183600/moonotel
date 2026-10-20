// Tests that the ratio sampler reads only decimal floating-point values from
// `OTEL_TRACES_SAMPLER_ARG`; MoonBit's `parse_double` also accepts digit
// separators, which must not leak through the environment variable.

///|
test "sampler_from_env_rejects_digit_separators_in_ratio" {
  @env.unset_env_var("OTEL_TRACES_SAMPLER")
  @env.unset_env_var("OTEL_TRACES_SAMPLER_ARG")
  @env.set_env_var("OTEL_TRACES_SAMPLER", "traceidratio")
  @env.set_env_var("OTEL_TRACES_SAMPLER_ARG", "0.1_0")
  let sampler = @sdk.Sampler::from_env()
  @env.unset_env_var("OTEL_TRACES_SAMPLER")
  @env.unset_env_var("OTEL_TRACES_SAMPLER_ARG")
  inspect(sampler.description(), content="TraceIdRatioBased{1}")
}
