# Wishlist

Feature ideas for future implementation.

---

## Recycling Fee Deck

### Description

A new deck that combines the Red Deck's bonus with a selling penalty.

### Mechanics

- **Base**: Same as Red Deck (+1 discard per round)
- **Modifier**: Selling any card costs $2 (instead of giving money)
- **Exception**: Egg joker is exempt from the selling fee (can be sold normally for profit)

### Implementation Notes

- Hook the card selling function to check for the deck modifier
- Check if card is Egg (`j_egg`) before applying the fee
- The $2 cost should be deducted from the player's money when selling
- If player has less than $2, they either:
  - Cannot sell the card (preferred - prevents going negative)
  - Or sell for $0 with no additional penalty

### Suggested Localization

```lua
b_cry_recycling_fee = {
    name = "Recycling Fee Deck",
    text = {
        "{C:red}+1{} discard",
        "every round",
        "Selling cards costs {C:money}$2{}",
        "{C:attention}Egg{} is exempt",
    },
},
```

### References

- Red Deck implementation for the +1 discard mechanic
- Card selling logic in the game for hooking the sell function
