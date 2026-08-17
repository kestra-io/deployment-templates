<policies>
  <inbound>
    <base />
    <rate-limit calls="${rate_limit_calls}" renewal-period="${rate_limit_period}" remaining-calls-header-name="x-ratelimit-remaining-calls" />
    <set-header name="api-key" exists-action="delete" />
    <set-header name="x-kestra-correlation-id" exists-action="skip">
      <value>@(context.RequestId.ToString())</value>
    </set-header>
    <set-query-parameter name="api-version" exists-action="override">
      <value>${api_version}</value>
    </set-query-parameter>
%{ if enable_observability ~}
    <llm-emit-token-metric namespace="KestraModelGateway">
      <dimension name="API ID" />
      <dimension name="Subscription ID" />
      <dimension name="Location" />
    </llm-emit-token-metric>
%{ endif ~}
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <base />
    <set-header name="x-kestra-correlation-id" exists-action="override">
      <value>@(context.Request.Headers.GetValueOrDefault("x-kestra-correlation-id", context.RequestId.ToString()))</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
