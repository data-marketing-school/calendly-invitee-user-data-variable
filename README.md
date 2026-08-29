# Enrich from Calendly API by DMS

A **Google Tag Manager Server-Side variable template** that calls the [Calendly API](https://developer.calendly.com/api-docs/8305c0ccfac70-get-event-invitee) from an invitee URI and returns a single object containing everything Calendly knows about the booking.

Built by [Data Marketing School](https://www.data-marketing-school.com/en) — written by [Lucas Rollin](https://www.linkedin.com/in/lucasrollin/).

## What it returns

One object merging:

- **Scheduled event details** — event type name, start and end time, location, guests, invitees counter, timestamps
- **Invitee user data** — email, phone number, first name and last name, already shaped as the `user_data` object expected by Google Ads, Meta and GA4 tags
- **UTM parameters** passed to Calendly (`utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `salesforce_uuid`)
- **Booking form answers** and, when applicable, **routing form answers**
- **Payment data** for paid meetings, with `transaction_id`, `value` and `currency` flattened to the top level

Keys that Calendly does not return are simply omitted.

```js
{
  // Scheduled event
  name: "30 Minute Meeting",
  start_time: "2026-08-31T07:00:00Z",
  end_time: "2026-08-31T07:30:00Z",
  location: { type: "google_conference", join_url: "https://..." },
  invitees_counter: { total: 1, active: 1, limit: 1 },
  event_created_at: "2026-08-29T15:49:46Z",
  event_updated_at: "2026-08-29T15:49:50Z",

  // Invitee
  timezone: "Europe/Paris",
  created_at: "2026-08-29T15:49:46Z",
  updated_at: "2026-08-29T15:49:46Z",
  scheduling_method: "instant_book",
  user_data: {
    email_address: "john.doe@acme.com",
    phone_number: "+33612345678",       // when available
    address: {
      first_name: "John",
      last_name: "Doe"
    }
  },

  // UTM parameters passed to Calendly
  tracking: {
    utm_source: "newsletter",
    utm_medium: "email",
    utm_campaign: "webinar"
  },

  // Booking form
  event_questions: ["How did you hear about us?"],
  event_answers: ["A newsletter"],
  event_answers_by_question: { "How did you hear about us?": "A newsletter" },

  // Routing form (when the invitee went through one)
  routing_form_questions: ["What is your budget?"],
  routing_form_answers: ["50k"],
  routing_form_answers_by_question: { "What is your budget?": "50k" },

  // Paid meetings only
  transaction_id: "ch_3Q7xKjL2eZvKYlo2",
  value: 150,
  currency: "EUR",
  payment_successful: true,
  payment: { provider: "stripe", amount: 150, currency: "EUR" }
}
```

### User data formatting

- The email is trimmed and lowercased, as the conversion APIs expect
- The phone number is read from the SMS reminder number, or otherwise detected among the booking form answers, and normalized to digits with a leading `+` when present
- First and last name come from Calendly's dedicated fields, or are split from the full name — a composed last name such as *de la Fontaine* is kept whole
- For a paid meeting, `transaction_id`, `value` and `currency` are exposed at the top level so a conversion tag can use them directly

## Fields

| Field | Required | Description |
| --- | --- | --- |
| **Personal Access Token** | Yes | Calendly API token used to authenticate every request. Store it in a **Constant** variable. |
| **Invitee URI** | Yes | The invitee to look up, in the form `https://api.calendly.com/scheduled_events/{event_uuid}/invitees/{invitee_uuid}`. The event UUID is read from this URI, so no separate event field is needed. |

### Personal Access Token

In Calendly, go to **Integrations & apps** → **API & Webhooks** → **Generate New Token**.

Required scopes:

- `scheduled_events:read` — **mandatory**, reads the event and the invitee
- `routing_forms:read` — *optional*, reads the routing form answers. Without it, every other piece of data is still returned and the routing form error is logged in the preview console.

> **Several hosts in your organization?** A token created by a regular member only reads that member's own meetings. Use a token created by an **admin** or an **owner** of the organization, otherwise some invitees return a 403 and others do not.

### Invitee URI

The URI can come from two sources:

1. **Calendly webhook** (server-side) — the `payload.uri` value of an `invitee.created` or `invitee.canceled` notification received by a client in your server container.
2. **Web tracking** — a Calendly listener in GTM Web pushes a `calendly_event_scheduled` event with the `invitee_uri` parameter, which is forwarded to the server container.

```html
<script>
window.addEventListener('message', function(e) {
  if (e.data.event && e.data.event.indexOf('calendly.') === 0) {
    if (e.data.event === 'calendly.event_scheduled') {
      window.dataLayer = window.dataLayer || [];
      window.dataLayer.push({
        event: 'calendly_event_scheduled',
        invitee_uri: e.data.payload.invitee.uri
      });
    }
  }
});
</script>
```

In both cases, read the value in the server container with an **Event Data** variable (key `invitee_uri` for the web tracking option).

> A reschedule creates a new invitee, so the invitee URI is not stable across reschedules.

## Using the returned object

The variable returns the whole object. Tags such as Google Ads, Meta or GA4 expect only the `user_data` part, so extract the property you need with an **Object Property Extractor** variable (also available in the server template gallery):

- **Object**: this Calendly variable
- **Property**: `user_data` (dotted notation is supported, e.g. `user_data.email_address`)

Create as many extractor variables as needed — `tracking` for the UTM parameters, `event_answers_by_question` for the booking form answers, `value` for a paid meeting, `start_time` for the meeting date, etc.

Then add the extracted `user_data` to the incoming event with an **Augment Event** transformation on `calendly_event_scheduled`, so every tag firing on that event can use it.

## How it works

The variable makes up to three calls to the Calendly API:

1. `GET /scheduled_events/{event_uuid}` — the meeting details
2. `GET /scheduled_events/{event_uuid}/invitees/{invitee_uuid}` — the invitee (**mandatory**)
3. `GET /routing_form_submissions/{uuid}` — the routing form answers, only when the invitee went through a routing form

Only the invitee call is required. If the other calls fail, the variable still returns the rest of the data and logs the reason in the preview console.

## Troubleshooting

If the variable is `undefined`, open the **Console** tab of the GTM Server preview — the reason is logged there.

| Message | Cause |
| --- | --- |
| `... is not a valid Calendly invitee URI` | The value does not have the shape `https://api.calendly.com/scheduled_events/{event_uuid}/invitees/{invitee_uuid}`. Check the Event Data variable and the web listener. |
| `401` | The Personal Access Token is missing, wrong or revoked. |
| `403` | The token lacks the `scheduled_events:read` scope, or it was created by a member who is not the host of that meeting. |
| `404` | The invitee no longer exists — for example after a reschedule, which creates a new invitee with a new URI. |

## Permissions

- **Send HTTP requests** to `https://api.calendly.com/scheduled_events/*` and `https://api.calendly.com/routing_form_submissions/*`
- **Log to console** in debug environments only

## Documentation

Full step-by-step guide: [Track Calendly meetings with Google Tag Manager Web and Server](https://data-marketing-school.com/en/blog/google-tag-manager/calendly-meetings/)

## License

[Apache License 2.0](LICENSE)
