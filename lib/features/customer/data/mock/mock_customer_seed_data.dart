import '../../domain/models/business.dart';
import '../../domain/models/delivery_order.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/product.dart';
import '../../../operations/domain/models/app_notification.dart';
import '../../../operations/domain/models/rider_location.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/role_application.dart';

class MockCustomerSeedData {
  const MockCustomerSeedData._();

  static const customerLatitude = 5.6037;
  static const customerLongitude = -0.1870;

  static final users = <AppUser>[
    const AppUser(
      id: 'demo-customer',
      name: 'Ama Boateng',
      email: 'customer@quickdeliver.demo',
      role: AppRole.customer,
      phoneNumber: '+233244100100',
      approvedRoles: [AppRole.customer],
    ),
    const AppUser(
      id: 'demo-owner',
      name: 'Efua Market',
      email: 'owner@quickdeliver.demo',
      role: AppRole.owner,
      phoneNumber: '+233244200200',
      approvedRoles: [AppRole.customer, AppRole.owner],
      ownerApplicationStatus: RoleApplicationStatus.approved,
    ),
    const AppUser(
      id: 'demo-rider',
      name: 'Kojo Mensah',
      email: 'rider@quickdeliver.demo',
      role: AppRole.rider,
      phoneNumber: '+233244300300',
      approvedRoles: [AppRole.customer, AppRole.rider],
      riderApplicationStatus: RoleApplicationStatus.approved,
    ),
  ];

  static final businesses = <Business>[
    const Business(
      id: 'biz-campus-bites',
      ownerId: 'demo-owner',
      name: 'Campus Bites',
      category: 'Restaurant',
      description:
          'Fast casual meals, bowls, and fresh smoothies popular with university students.',
      address: '15 University Avenue, East Legon',
      phoneNumber: '+233244000111',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      rating: 4.8,
      estimatedDeliveryMinutes: 24,
      latitude: 5.6402,
      longitude: -0.1668,
      tags: ['Top rated', 'Lunch deals', 'Fast prep'],
    ),
    const Business(
      id: 'biz-city-pharmacy',
      ownerId: 'demo-owner',
      name: 'City Pharmacy',
      category: 'Pharmacy',
      description:
          'Trusted neighbourhood pharmacy for health essentials and urgent medicine pickups.',
      address: '7 Boundary Road, Shiashie',
      phoneNumber: '+233244000222',
      imageUrl:
          'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?auto=format&fit=crop&w=900&q=80',
      rating: 4.7,
      estimatedDeliveryMinutes: 19,
      latitude: 5.6389,
      longitude: -0.1712,
      tags: ['Express', 'Medical', 'Essential care'],
    ),
    const Business(
      id: 'biz-fresh-basket',
      ownerId: 'demo-owner',
      name: 'Fresh Basket',
      category: 'Groceries',
      description:
          'Curated groceries, produce, and pantry staples for same-day neighborhood delivery.',
      address: '22 Lagos Avenue, Cantonments',
      phoneNumber: '+233244000333',
      imageUrl:
          'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=900&q=80',
      rating: 4.9,
      estimatedDeliveryMinutes: 31,
      latitude: 5.5777,
      longitude: -0.1648,
      tags: ['Fresh produce', 'Family packs', 'Popular'],
    ),
  ];

  static final products = <Product>[
    const Product(
      id: 'prd-jollof',
      businessId: 'biz-campus-bites',
      name: 'Chicken Jollof Bowl',
      description:
          'Smoky jollof rice, grilled chicken, plantain, and house slaw.',
      category: 'Meals',
      price: 38.0,
      imageUrl:
          'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=900&q=80',
      isAvailable: true,
      preparationMinutes: 18,
    ),
    const Product(
      id: 'prd-smoothie',
      businessId: 'biz-campus-bites',
      name: 'Tropical Mango Smoothie',
      description: 'Fresh mango, pineapple, yogurt, and a touch of ginger.',
      category: 'Drinks',
      price: 16.0,
      imageUrl:
          'https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?auto=format&fit=crop&w=900&q=80',
      isAvailable: true,
      preparationMinutes: 6,
    ),
    const Product(
      id: 'prd-pain-relief',
      businessId: 'biz-city-pharmacy',
      name: 'Pain Relief Pack',
      description:
          'Fast-access essentials for headache, body pain, and mild fever support.',
      category: 'Medicine',
      price: 28.5,
      imageUrl:
          'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=900&q=80',
      isAvailable: true,
      preparationMinutes: 8,
    ),
    const Product(
      id: 'prd-vitamin-c',
      businessId: 'biz-city-pharmacy',
      name: 'Vitamin C Boost',
      description: 'Immune support tablets for daily wellness routines.',
      category: 'Supplements',
      price: 34.0,
      imageUrl:
          'https://images.unsplash.com/photo-1607619056574-7b8d3ee536b2?auto=format&fit=crop&w=900&q=80',
      isAvailable: true,
      preparationMinutes: 5,
    ),
    const Product(
      id: 'prd-veggie-box',
      businessId: 'biz-fresh-basket',
      name: 'Weekly Veggie Box',
      description:
          'Mixed tomatoes, onions, peppers, carrots, and greens for home cooking.',
      category: 'Produce',
      price: 52.0,
      imageUrl:
          'https://images.unsplash.com/photo-1610348725531-843dff563e2c?auto=format&fit=crop&w=900&q=80',
      isAvailable: true,
      preparationMinutes: 14,
    ),
    const Product(
      id: 'prd-breakfast-kit',
      businessId: 'biz-fresh-basket',
      name: 'Breakfast Essentials Kit',
      description:
          'Bread, eggs, milk, cereal, and bananas in one quick bundle.',
      category: 'Bundles',
      price: 44.0,
      imageUrl:
          'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=900&q=80',
      isAvailable: true,
      preparationMinutes: 11,
    ),
  ];

  static final initialOrders = <DeliveryOrder>[
    DeliveryOrder(
      id: 'QD-1008',
      businessId: 'biz-campus-bites',
      businessName: 'Campus Bites',
      customerId: 'demo-customer',
      customerName: 'Ama Boateng',
      customerPhone: '+233244100100',
      deliveryAddress: 'Hostel Block C, East Legon',
      status: OrderStatus.preparing,
      businessPhone: '+233244000111',
      riderId: 'demo-rider',
      riderName: 'Kojo Mensah',
      riderPhone: '+233244300300',
      trackingEnabled: true,
      items: const [
        OrderItem(
          productId: 'prd-jollof',
          productName: 'Chicken Jollof Bowl',
          unitPrice: 38.0,
          quantity: 1,
          imageUrl:
              'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=900&q=80',
        ),
      ],
      createdAt: DateTime(2026, 4, 8, 13, 45),
      note: 'No pepper please.',
    ),
    DeliveryOrder(
      id: 'QD-1004',
      businessId: 'biz-fresh-basket',
      businessName: 'Fresh Basket',
      customerId: 'demo-customer',
      customerName: 'Ama Boateng',
      customerPhone: '+233244100100',
      deliveryAddress: 'Ring Road apartment 4B',
      status: OrderStatus.delivered,
      businessPhone: '+233244000333',
      riderId: 'demo-rider',
      riderName: 'Kojo Mensah',
      riderPhone: '+233244300300',
      pickupProofImageUrl:
          'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=900&q=80',
      deliveryProofImageUrl:
          'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?auto=format&fit=crop&w=900&q=80',
      trackingEnabled: true,
      items: const [
        OrderItem(
          productId: 'prd-breakfast-kit',
          productName: 'Breakfast Essentials Kit',
          unitPrice: 44.0,
          quantity: 1,
          imageUrl:
              'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=900&q=80',
        ),
      ],
      createdAt: DateTime(2026, 4, 6, 9, 10),
    ),
    DeliveryOrder(
      id: 'QD-1002',
      businessId: 'biz-city-pharmacy',
      businessName: 'City Pharmacy',
      customerId: 'demo-customer',
      customerName: 'Ama Boateng',
      customerPhone: '+233244100100',
      deliveryAddress: 'Airport Residential apartment 2A',
      status: OrderStatus.ready,
      businessPhone: '+233244000222',
      items: const [
        OrderItem(
          productId: 'prd-vitamin-c',
          productName: 'Vitamin C Boost',
          unitPrice: 34.0,
          quantity: 1,
          imageUrl:
              'https://images.unsplash.com/photo-1607619056574-7b8d3ee536b2?auto=format&fit=crop&w=900&q=80',
        ),
      ],
      createdAt: DateTime(2026, 4, 9, 8, 30),
      note: 'Please ring once on arrival.',
    ),
  ];

  static final riderLocations = <RiderLocation>[
    RiderLocation(
      riderId: 'demo-rider',
      riderName: 'Kojo Mensah',
      latitude: 5.6120,
      longitude: -0.1810,
      updatedAt: DateTime(2026, 4, 9, 9, 15),
      orderId: 'QD-1008',
      isActive: true,
    ),
  ];

  static final notifications = <AppNotification>[
    AppNotification(
      id: 'notif-1',
      userId: 'demo-customer',
      title: 'Order is being prepared',
      body: 'Campus Bites has started preparing your Chicken Jollof Bowl.',
      type: AppNotificationType.orderStatus,
      orderId: 'QD-1008',
      createdAt: DateTime(2026, 4, 9, 9, 10),
    ),
    AppNotification(
      id: 'notif-2',
      userId: 'demo-owner',
      title: 'New incoming order',
      body: 'Order QD-1002 is ready for review and rider assignment.',
      type: AppNotificationType.orderStatus,
      orderId: 'QD-1002',
      createdAt: DateTime(2026, 4, 9, 8, 35),
    ),
  ];
}
