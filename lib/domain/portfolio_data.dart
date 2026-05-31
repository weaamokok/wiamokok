import 'package:flutter/material.dart';
import 'project.dart';
import 'experience.dart';

class PortfolioData {
  static const name = 'Wiam Okok';
  static const title = 'Mobile Engineer';
  static const tagline = 'Building polished,\nfast Flutter apps.';
  static const bio =
      '3 years crafting mobile experiences — from startup MVPs to production apps used by real people. '
      'I care about smooth animations, clean architecture, and shipping things that work.';
  static const email = 'weamokok@gmail.com';
  static const github = 'https://github.com/weaamokok';

  static const skills = [
    'Flutter',
    'Dart',
    'Riverpod',
    'Firebase',
    'REST APIs',
    'Animations',
    'UI/UX',
    'Git',
    'Figma',
    'Android',
    'iOS',
  ];

  static final projects = <Project>[
    Project(
      id: 'p1',
      title: 'Published App',
      subtitle: 'Live on the App Store & Play Store',
      description:
          'A production app shipped to thousands of users. Built with Flutter, Riverpod, and Firebase — '
          'featuring real-time sync, push notifications, and a polished onboarding experience.',
      tags: ['Flutter', 'Firebase', 'Riverpod', 'Published'],
      status: ProjectStatus.published,
      accentColor: const Color(0xFFFF5C35),
    ),
    Project(
      id: 'p2',
      title: 'Glow — Wellness Tracker',
      subtitle: 'Unreleased — personal project',
      description:
          'A habit and wellness tracking app with a deeply custom schedule engine. '
          'Features skeleton loading states, offline-first architecture, and fluid page transitions.',
      tags: ['Flutter', 'Riverpod', 'Sembast', 'Animations'],
      status: ProjectStatus.unreleased,
      accentColor: const Color(0xFF1A1A1A),
    ),
    Project(
      id: 'p3',
      title: 'Finance Dashboard',
      subtitle: 'Unreleased — freelance project',
      description:
          'A mobile banking dashboard with real-time balance updates, transaction history, '
          'and card management. Designed around a card-first layout with gesture-driven navigation.',
      tags: ['Flutter', 'Dio', 'Charts', 'Auto Route'],
      status: ProjectStatus.unreleased,
      accentColor: const Color(0xFF2D2D2D),
    ),
    Project(
      id: 'p4',
      title: 'E-Commerce App',
      subtitle: 'Unreleased — freelance project',
      description:
          'End-to-end shopping experience: product catalogue, cart, checkout with Stripe, '
          'and order tracking. Localized in Arabic and English with RTL layout support.',
      tags: ['Flutter', 'Stripe', 'Slang', 'RTL'],
      status: ProjectStatus.unreleased,
      accentColor: const Color(0xFF3D2B1F),
    ),
  ];

  static final experiences = <Experience>[
    Experience(
      company: 'Full-time Position',
      role: 'Flutter Developer',
      period: '2023 – Present',
      description:
          'Building and maintaining production Flutter apps. Responsible for architecture decisions, '
          'code reviews, and mentoring junior devs.',
      tags: ['Flutter', 'Firebase', 'CI/CD'],
    ),
    Experience(
      company: 'Freelance',
      role: 'Mobile App Developer',
      period: '2022 – Present',
      description:
          'Delivered 5+ apps for clients across e-commerce, health, and fintech. '
          'End-to-end ownership from Figma handoff to App Store submission.',
      tags: ['Flutter', 'Client Work', 'App Store'],
      isFreelance: true,
    ),
  ];
}
