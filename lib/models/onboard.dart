class OnboardingContent {
  final String imagePath;
  final String title;
  final String description;
  final String buttonText;

  OnboardingContent({
    required this.imagePath,
    required this.title,
    required this.description,
    required this.buttonText,
  });
}

List<OnboardingContent> contents = [
  OnboardingContent(
    imagePath:
        'assets/images/doctor_reminder.jpg', // Replace with your file names
    title: 'Take control of your health with personalized reminders.',
    description:
        'Create medication and checkup reminders in simple steps and never miss a dose.',
    buttonText: 'Next',
  ),
  OnboardingContent(
    imagePath: 'assets/images/collabration.jpg', // Replace with your file names
    title: 'Enjoy accessibility and health collaboration.',
    description:
        'Listen to medication instructions, connect with doctors and caregivers, and link health devices.',
    buttonText: 'Next',
  ),
  OnboardingContent(
    imagePath: 'assets/images/elderly_care.jpg', // Replace with your file names
    title: 'Care and support for your loved ones remotely.',
    description:
        'Monitor their health, keep them on track, and get notified when they have any emergency.',
    buttonText: 'Get started',
  ),
];
