enum PresetCategory { pass, askInfo, followUp }

/// Reusable preset message template for custom request interactions.
class AutoResponsePreset {
  final String id;
  final String title;
  final PresetCategory category;
  final String messageTemplate;
  final String? connectedActionTitle;

  const AutoResponsePreset({
    required this.id,
    required this.title,
    required this.category,
    required this.messageTemplate,
    this.connectedActionTitle,
  });

  static const List<AutoResponsePreset> defaultPassPresets = [
    AutoResponsePreset(
      id: 'pass_style',
      title: 'Outside my style',
      category: PresetCategory.pass,
      messageTemplate:
          "Thanks so much for thinking of me! This idea isn't really my style, and you deserve someone who specializes in it.",
      connectedActionTitle: 'Recommend other Flash artists',
    ),
    AutoResponsePreset(
      id: 'pass_capacity',
      title: 'Too big for current books',
      category: PresetCategory.pass,
      messageTemplate:
          "I love this idea, but I can't fit a piece this size into my current booking window.",
      connectedActionTitle: 'Join waitlist for next drop',
    ),
    AutoResponsePreset(
      id: 'pass_booked',
      title: 'Books filled up',
      category: PresetCategory.pass,
      messageTemplate:
          "My books filled up before I could take this on. I'd love to get you in next time!",
      connectedActionTitle: 'Join waitlist + available flash',
    ),
    AutoResponsePreset(
      id: 'pass_placement',
      title: 'Placement not done',
      category: PresetCategory.pass,
      messageTemplate:
          "I don't tattoo this placement, but I'd be happy to discuss a different placement.",
      connectedActionTitle: 'Resubmit with different placement',
    ),
    AutoResponsePreset(
      id: 'pass_flash_only',
      title: 'Flash-only right now',
      category: PresetCategory.pass,
      messageTemplate:
          "I'm only accepting flash at the moment. Take a look at my available pieces!",
      connectedActionTitle: 'Browse available flash',
    ),
  ];

  static const List<AutoResponsePreset> defaultAskInfoPresets = [
    AutoResponsePreset(
      id: 'ask_size',
      title: 'Size in inches',
      category: PresetCategory.askInfo,
      messageTemplate: '• Approximate size in inches',
    ),
    AutoResponsePreset(
      id: 'ask_placement',
      title: 'Exact placement',
      category: PresetCategory.askInfo,
      messageTemplate: '• Exact placement on your body',
    ),
    AutoResponsePreset(
      id: 'ask_references',
      title: 'Reference photos',
      category: PresetCategory.askInfo,
      messageTemplate:
          '• 1–2 reference photos of the style/elements you have in mind',
    ),
    AutoResponsePreset(
      id: 'ask_color',
      title: 'Color vs B&G',
      category: PresetCategory.askInfo,
      messageTemplate:
          '• Whether you are picturing this in color or black & grey',
    ),
    AutoResponsePreset(
      id: 'ask_budget',
      title: 'Budget range',
      category: PresetCategory.askInfo,
      messageTemplate: '• Your target budget range for this piece',
    ),
    AutoResponsePreset(
      id: 'ask_coverup',
      title: 'Existing tattoos / cover-up',
      category: PresetCategory.askInfo,
      messageTemplate:
          '• Whether this will go over or next to any existing tattoos or scars',
    ),
  ];
}
