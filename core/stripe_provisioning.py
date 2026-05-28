"""Stripe webhook handlers for CTG Pro keys — no PAN, no full payment payloads stored."""

from __future__ import annotations

from typing import Any, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from db.pro_keys import ProKeyStore

_ACTIVE_SUB_STATUSES = frozenset({"active", "trialing"})


def _customer_id_from_subscription(sub: dict[str, Any]) -> str:
    return str(sub.get("customer") or "").strip()


def _email_from_session(session: dict[str, Any]) -> str:
    details = session.get("customer_details") or {}
    return str(details.get("email") or "").strip()


def handle_provision_event(
    event: dict[str, Any],
    store: Optional["ProKeyStore"],
) -> dict[str, Any]:
    """
    Map Stripe webhook events to Pro key provision/revoke actions.

    Safe to call from stripe_provision.py or tests. Never logs secrets or card data.
    """
    etype = str(event.get("type") or "")
    result: dict[str, Any] = {"ok": True, "type": etype}

    if store is None:
        result["skipped"] = "no_store"
        return result

    obj = (event.get("data") or {}).get("object") or {}

    if etype == "checkout.session.completed":
        session = obj
        mode = str(session.get("mode") or "")
        customer_id = str(session.get("customer") or session.get("id") or "").strip()
        if not customer_id:
            result["skipped"] = "no_customer"
            return result
        email = _email_from_session(session)
        existing = store.find_by_customer(customer_id)
        api_key = existing or store.provision(customer_id, email=email)
        result["api_key"] = api_key
        result["customer_id"] = customer_id
        result["mode"] = mode
        return result

    if etype in ("customer.subscription.created", "customer.subscription.updated"):
        sub = obj
        customer_id = _customer_id_from_subscription(sub)
        status = str(sub.get("status") or "")
        if not customer_id:
            result["skipped"] = "no_customer"
            return result
        if status not in _ACTIVE_SUB_STATUSES:
            result["skipped"] = f"status_{status}"
            return result
        existing = store.find_by_customer(customer_id)
        if existing:
            result["api_key"] = existing
            result["customer_id"] = customer_id
            result["action"] = "existing"
            return result
        api_key = store.provision(customer_id, email="")
        result["api_key"] = api_key
        result["customer_id"] = customer_id
        result["action"] = "provisioned"
        return result

    if etype == "customer.subscription.deleted":
        sub = obj
        customer_id = _customer_id_from_subscription(sub)
        existing = store.find_by_customer(customer_id) if customer_id else None
        if existing:
            store.revoke(existing)
            result["revoked"] = existing
            result["customer_id"] = customer_id
        else:
            result["skipped"] = "no_active_key"
        return result

    if etype == "invoice.payment_failed":
        sub_id = str(obj.get("subscription") or "")
        result["skipped"] = "invoice_handled_by_stripe_dunning"
        result["subscription"] = sub_id
        return result

    result["skipped"] = "unhandled_type"
    return result
